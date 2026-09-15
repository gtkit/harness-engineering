# 共享状态 Guide（shared dict / lrucache / lock）

Nginx 是多 worker 多进程模型，每个 worker 一个独立的 LuaJIT VM。**模块级变量只在本 worker 内有效**，
四个 worker 就是四份互不相通的状态。选存储前先确认要共享到什么范围：

| 范围 | 用什么 | 能存什么 | 代价 |
| --- | --- | --- | --- |
| 单个请求内 | `ngx.ctx` | 任意 Lua 值 | 每请求建表 |
| 单 worker 内跨请求 | `lua-resty-lrucache` | **任意 Lua 值，含 table** | 无锁，无跨 worker 一致性 |
| 全部 worker 共享 | `lua_shared_dict` | **只有 string / number / boolean** | 每次读写走共享内存 + 锁，需序列化 |
| 跨机器 | Redis | 序列化后的字符串 | 一次网络往返 |

下面的行为都在 OpenResty 1.27.1.2 上实测得到。

## shared dict 的四个硬约束

**1. 存不了 table。** 实测 `dict:set("t", {1,2})` 返回 `nil, "bad value type"`，不抛错——
不检查返回值就会得到一个"写成功了"的假象。存结构化数据必须先 `cjson.encode`，读出来再 `decode`，
这笔序列化开销要算进选型判断里；数据结构复杂且只需本 worker 可见时，lrucache 更合适。

**2. 满了会淘汰别人的 key，而且不报错。** 实测 `lua_shared_dict cache 1m` 声明 1MB，
`capacity()` 返回 1048576，但存 8KB 的 value **只存进 85 个（约 696KB）就开始强制淘汰**，
且被淘汰的是最久未用的其他 key——测试里先写入的 `k` 被无声踢掉了。

```lua
local ok, err, forcible = dict:set(key, val)
-- forcible == true 表示这次写入淘汰了别的 key，说明容量已经不够
```

约定：**每个 `set` 都接住第三个返回值 `forcible`**，为真时至少打一条 WARN 日志。
这是容量不足唯一的早期信号，没有它，缓存命中率会在某天悄悄塌掉而没有任何报错。

容量估算按**声明容量的三分之二**算可用空间（上面那次实测是 696KB / 1MB ≈ 66%，
剩余是 slab 分配器的分片与元数据开销；实际比例随 value 大小变化，大 value 更浪费），
并在 `init_worker` 里用 `dict:free_space()` 打一条启动日志，方便事后核对。
注意 `free_space()` 返回的是完全空闲的 slab 页，不含已分配页里的碎片，它偏小。

**3. `incr` 不带 init 参数会失败。** 实测 `dict:incr("cnt", 1)` 在 key 不存在时返回
`nil, "not found"`。计数场景一律写第三个参数：

```lua
local newval, err = dict:incr(key, 1, 0)   -- 第三个参数是 key 不存在时的初始值
```

**4. 过期的值还能取到。** `dict:get_stale(key)` 会返回已过期但尚未被回收的值
（实测过期后 `get` 返回 nil，同一时刻 `get_stale` 仍返回原值）。这是做缓存击穿保护的关键工具：
回源失败时降级返回 stale 数据，比向客户端报 500 好。

## 缓存击穿防护

热点 key 过期的瞬间，全部并发请求同时穿透到后端。标准做法是 `resty.lock`（实测可用）：

```lua
local resty_lock = require "resty.lock"

local function get_with_lock(key)
    local val = cache:get(key)
    if val then return val end

    local lock, err = resty_lock:new("locks")      -- "locks" 是另一个 shared dict
    if not lock then return nil, err end

    local elapsed, err = lock:lock(key)
    if not elapsed then return nil, err end

    -- 二次检查：等锁期间别人可能已经回填
    val = cache:get(key)
    if val then
        lock:unlock()
        return val
    end

    local fresh, err = fetch_from_upstream(key)
    if not fresh then
        lock:unlock()
        return cache:get_stale(key)                 -- 回源失败降级到 stale
    end

    cache:set(key, fresh, TTL)
    lock:unlock()
    return fresh
end
```

三个必须做到的点：**拿到锁后二次检查缓存**（否则等锁的请求仍会挨个回源）；
**每条返回路径都 unlock**（含错误路径，漏一条就把该 key 锁到超时为止）；
**锁用独立的 shared dict**，和数据缓存混在一个 dict 里时，数据把空间占满会导致锁写入失败。

`resty.lock` 是 worker 间的锁，不是跨机器的锁。多机部署下每台机器各自回源一次是可以接受的；
需要全局唯一回源时用 Redis 锁，见 `.harness/guides/upstream-and-io.md`。

## lrucache 的定位

```lua
local lrucache = require "resty.lrucache"
local c = lrucache.new(200)      -- 200 是条目数上限，不是字节数
```

存 table 不需要序列化（实测直接存取 table 正常），无锁，速度远快于 shared dict。
代价是每个 worker 一份：4 个 worker 就是 4 份副本、4 次回源、最多 4 份不一致的数据。

用它的前提是**数据可以短时间不一致**。配置、字典表、编译好的正则这类适合；
计数器、限流额度、幂等标记这类必须用 shared dict 或 Redis。

`lrucache.new()` 要在**模块顶层**调用一次，让它成为模块级变量；放进请求处理函数里
等于每请求新建一个空缓存，命中率恒为零——这是最常见的误用。

## 定时器与 worker

`ngx.timer.at` 创建的定时器**每个 worker 都会各跑一份**。在 `init_worker_by_lua` 里起周期任务
（刷新配置、上报指标）时，如果任务只应执行一次，用 worker id 判断：

```lua
if ngx.worker.id() == 0 then
    ngx.timer.every(60, refresh_config)
end
```

定时器数量受 `lua_max_running_timers` / `lua_max_pending_timers` 限制，
`ngx.timer.at` 的返回值要检查——超限时返回 `nil, "too many pending timers"`。

## 检查项

- [ ] 存进 shared dict 的是 string / number / boolean，table 已 `cjson.encode`
- [ ] 每个 `dict:set` 都检查了 `ok` 与 `forcible`
- [ ] shared dict 容量按声明值的 70% 估算，并有启动日志记录 `free_space()`
- [ ] `dict:incr` 带了 init 参数
- [ ] 热点 key 有击穿防护，拿锁后做了二次检查，所有路径都 unlock
- [ ] 锁用的是独立的 shared dict
- [ ] lrucache 实例在模块顶层创建，且该数据允许 worker 间不一致
- [ ] 只应执行一次的定时任务用 `ngx.worker.id() == 0` 限定
