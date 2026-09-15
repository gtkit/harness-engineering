# 出站 IO Guide（cosocket / 连接池 / 超时）

## 唯一铁律：不许阻塞 worker

一个 worker 用单线程事件循环处理成百上千个并发请求。任何阻塞调用都会把该 worker 上**所有**
请求一起卡住，症状是随机的、间歇性的超时，排查成本极高。

禁止出现在任何请求路径上的调用：

| 阻塞写法 | 非阻塞替代 |
| --- | --- |
| `os.execute` / `io.popen` | 没有等价物；确需外部命令时丢给 `ngx.timer` 并接受其后果 |
| `io.open` + `read` 读大文件 | 启动期读进内存，或用 `ngx.location.capture` 走 Nginx 静态处理 |
| `socket.*`（LuaSocket） | `ngx.socket.tcp`（cosocket） |
| 纯 Lua 的 `sleep` 忙等 | `ngx.sleep`（yield，不阻塞） |
| 同步的第三方 Lua 库（未标注 non-blocking） | 找 `lua-resty-*` 对应实现 |

引入任何新的第三方 Lua 库之前，先确认它是基于 cosocket 的。库名以 `lua-resty-` 开头
不是充分证据，要看它内部用的是 `ngx.socket` 还是 `socket`。

## 每个连接都必须回收

cosocket 连接不回收就是每请求一次 TCP 握手，高并发下端口耗尽。所有出站客户端
（`resty.mysql` / `resty.redis` / `resty.http`）的用法都是同一个骨架：

```lua
local red, err = redis:new()
if not red then return nil, err end

red:set_timeout(1000)                          -- 连接/发送/读取统一超时
local ok, err = red:connect(host, port)
if not ok then return nil, err end

-- ... 业务命令 ...

-- 正常路径：放回连接池，不要 close
red:set_keepalive(60000, 100)                  -- 最大空闲 60s，池大小 100
```

关键点：

- **正常结束用 `set_keepalive`，不用 `close`。** `close` 会真的断开 TCP，下次请求重新握手。
- **出错路径用 `close`。** 连接出错后状态不可信（可能还有未读完的响应），放回池里会污染
  下一个使用者，表现为"随便哪个接口偶尔返回别的接口的数据"。
- **每条 return 路径都要处理连接。** 中途 `return nil, err` 时漏掉回收，该连接会一直挂到 GC。
- **`set_keepalive` 之后不能再用这个对象。** 它已经回到池里，可能已被另一个请求取走。

连接池默认按 `host:port` 分桶——**认证信息与选中的 db 不在分桶键里**，这正是下一节那些坑的根源；
需要隔离时用 `connect` 的 `pool` 选项显式指定池名。池大小要与后端的最大连接数对齐：
`worker_processes × pool_size` 不能超过 MySQL 的 `max_connections`。4 个 worker × 100
就是 400 个连接，这个数字要真算一遍，不要照抄示例值。

## 认证与连接池的坑

从池里取出的连接**已经认证过**，重复 `auth` 是一次无谓的往返；但如果连接是新建的，
不 `auth` 又会失败。`resty.redis` 用 `get_reused_times()` 区分：

```lua
local times, err = red:get_reused_times()
if times == 0 then                      -- 0 表示新建连接
    local ok, err = red:auth(password)
    if not ok then
        red:close()
        return nil, err
    end
end
```

同理，`select` 切换 Redis db 也只需在新连接上做一次，但要注意：切过 db 的连接放回池后
**下一个使用者拿到的仍然是切过的连接**。多 db 混用时必须在每次取出后显式 `select`，
或者干脆给每个 db 用独立的连接池（`connect` 时传不同的 `pool` 名）。

## 超时预算

每一跳的超时必须小于它的调用方还剩多少时间，否则外层早已放弃、内层还在傻等：

```text
客户端超时 10s
  └─ Nginx send_timeout / lua_socket_*_timeout
       └─ 本次请求预算 5s
            ├─ Redis   200ms   （缓存，快失败快降级）
            └─ MySQL   2000ms  （主查询）
```

`set_timeout(ms)` 设的是连接、发送、读取三个阶段各自的超时，不是总耗时。
三个阶段都可能各花掉这么久，真实最坏耗时是它的数倍——按阶段分别设置用
`set_timeouts(connect, send, read)` 更可控。

超时值写成模块顶部的具名常量，不要散落在调用处的字面量里。

## 失败处理

出站依赖一定会失败，每个调用点都要明确回答三个问题，答不上来就是没写完：

1. **失败了返回什么？** 缓存可以降级到 stale 或空结果；主数据库查询失败只能报错。
2. **重试吗？** 只有确定幂等的操作才重试（读查询可以，`INSERT` 不行）。
   重试要有次数上限和退避，且总耗时仍在本请求预算内。
3. **日志里有没有定位所需的信息？** 至少包含操作对象（哪个 key / 哪张表）和错误原文，
   不要只打一句 `"redis error"`。

`ngx.log(ngx.ERR, ...)` 的参数会被直接拼接，不要用 `..` 预拼，多传几个参数更省。

## SQL 与注入

`resty.mysql` 没有预处理语句，拼 SQL 是唯一方式，所以**每个来自外部的值都必须经过
`ngx.quote_sql_str`**：

```lua
local sql = "SELECT * FROM users WHERE token = " .. ngx.quote_sql_str(token)
```

`quote_sql_str` 负责加引号和转义，**不要自己再补引号**（`'" .. quote(x) .. "'` 是错的）。
表名、列名、`ORDER BY` 字段无法用它处理——这类拼接只允许用代码里的白名单常量，
不允许任何外部输入参与。

查询结果里 `NULL` 是 `ngx.null`，`DECIMAL` 是字符串，见
`.harness/guides/data-encoding.md`。

## 检查项

- [ ] 请求路径上没有阻塞调用
- [ ] 每个连接在正常路径 `set_keepalive`、错误路径 `close`，没有遗漏的 return 分支
- [ ] `set_keepalive` 之后没有再使用该连接对象
- [ ] 连接池大小 × worker 数不超过后端承载能力
- [ ] 认证 / `select` 用 `get_reused_times()` 判断，或使用独立 pool 名
- [ ] 每一跳超时都小于上游剩余预算，超时值是具名常量
- [ ] 每个失败路径都定义了返回值、重试策略与可定位的日志
- [ ] 所有进入 SQL 的外部值都过了 `ngx.quote_sql_str`，且没有重复加引号
