# Lua 语言基线 Guide（LuaJIT 2.1）

## 唯一基线：项目实际跑的运行时

写任何 Lua 之前先确认运行时，不要凭"最新 Lua 是 5.4"下笔：

```bash
openresty -v                 # 或 nginx -V 2>&1 | head -1
resty -e 'print(_VERSION, jit and jit.version)'
```

OpenResty 里跑的是 **LuaJIT 2.1**，语言层面是 **Lua 5.1 语义**，额外补了一部分 5.2/5.3 的库函数和语法。
PUC-Rio Lua 5.4 的新语法在这里**无法解析**——不是"不推荐"，是 `loadstring` 直接报语法错误。
把 5.3/5.4 的写法带进 OpenResty 项目，错误只会在请求到达那一刻以 500 的形式暴露出来。

下表是在 OpenResty 1.27.1.2 / LuaJIT 2.1.ROLLING 上逐条实测的结果。换机器或换版本后，用
`.harness/guides/validation-and-release.md` 里的探测脚本重测，不要照抄这张表当永久事实。

## 可以用（LuaJIT 2.1 已实现）

| 特性 | 归属版本 | 说明 |
| --- | --- | --- |
| `goto` / `::label::` | 5.2 | 可用。多层循环跳出比 flag 变量清晰 |
| `table.pack` / `table.unpack` | 5.2 | 可用；全局 `unpack` 也仍在（5.1 遗留） |
| `table.move` | 5.3 | 可用 |
| `rawlen` | 5.2 | 可用 |
| `coroutine.isyieldable` | 5.2 | 可用 |
| `xpcall` 传额外参数 | 5.2 | 可用 |
| `0x1p4` 十六进制浮点字面量 | 5.2 | 可用 |
| `1LL` / `2ULL` 整数字面量 | LuaJIT 扩展 | 可用，产生 64 位 cdata（见下方「64 位整数」） |
| `require "bit"` | LuaJIT 扩展 | 位运算的唯一入口 |
| `require "ffi"` | LuaJIT 扩展 | 可用，但在 OpenResty 里属高风险，见下 |
| `require "table.new"` / `"table.clear"` | LuaJIT 扩展 | 预分配与复用表，热路径减 GC |
| `require "string.buffer"` | LuaJIT 2.1 扩展 | 大量字符串拼接优先用它，比 `..` 连接省分配 |
| `setfenv` / `loadstring` | 5.1 | 仍在（5.2 已移除，这里还能用） |

## 不能用（语法解析直接失败）

| 写法 | 归属版本 | 实测报错 | 替代 |
| --- | --- | --- | --- |
| `7 // 2` | 5.3 | `unexpected symbol near '/'` | `math.floor(7 / 2)` |
| `5 & 3`、`1 \| 2`、`1 << 8`、`~5` | 5.3 | `unexpected symbol near` | `local bit = require "bit"`，用 `bit.band` / `bor` / `lshift` / `bnot` |
| `local x <const> = 1` | 5.4 | `unexpected symbol near '<'` | 普通 `local` |
| `local f <close> = ...` | 5.4 | `unexpected symbol near '<'` | 显式 `pcall` + 清理，或 `ngx.on_abort` |

同样不存在的库函数：`string.pack` / `string.unpack`、`math.type`、`math.tointeger`、
`math.maxinteger` / `math.mininteger`、`coroutine.close`、`warn`。用到时会是
`attempt to call a nil value`，不是语法错误，更难定位——写之前先确认。

## 数字只有 double，没有整数类型

Lua 5.3 起区分 integer 与 float，LuaJIT 2.1 没有：所有 `number` 都是 64 位 double。
由此产生的实测行为：

```lua
tostring(3)          --> "3"        （不会打印成 3.0）
2^53 + 1 == 2^53     --> true       （超过 2^53 后相邻整数无法区分）
tostring(2^53)       --> "9.007199254741e+15"
#"中文"              --> 6          （# 是字节数，不是字符数）
```

**订单号、雪花 ID、用户 ID 这类大整数一律按字符串处理**，从 MySQL / Redis 取出到编码进
JSON 的整条链路都不要让它变成 number。具体的 JSON 编码行为和精度损失见
`.harness/guides/data-encoding.md`，那是本仓库这块的单一真源。

需要真正的 64 位整数运算时用 `1LL` / `ffi.new("int64_t")` 产生的 cdata，但注意 cdata
不能直接塞给 `cjson.encode`，也不能当 table 的 key 用——跨出运算范围前先 `tostring`。

## FFI 在 OpenResty 里的使用门槛

`ffi` 可用，但它绕过了 Lua 的所有安全网：一次越界写就是 worker 段错误，整个 worker
上正在处理的全部请求一起断。只在这三个条件同时满足时才用：现有 `lua-resty-*` 库解决不了、
调用的是无阻塞的纯计算 C 函数、结构体布局在代码注释里写明来源头文件与版本。
`ffi.cdef` 只能在模块顶层执行一次（重复 cdef 同一符号会抛错），不要放进请求处理路径。

## 局部化与热路径

顶部把用到的 `ngx.*` 和标准库函数 `local` 化，是 OpenResty 的既有惯例，也是本仓库现有代码的风格：

```lua
local ngx_log    = ngx.log
local ngx_ERR    = ngx.ERR
local cjson      = require "cjson.safe"
local tab_concat = table.concat
```

原因是 LuaJIT 对 upvalue 的访问比连续的 table 查找快，而且 `local` 化后哪些 API 被用到一目了然。
匹配这个风格，不要在函数体里反复写 `ngx.xxx`。

需要避免的反向操作：不要为了"看起来整洁"把热路径上的小函数拆成多层调用；不要在请求路径上
用 `string.format` 拼日志（先判断日志级别再拼）。性能判断以实测为准，不凭感觉改写。

## 每次改完 Lua 必须做的语法检查

LuaJIT 没有编译期，语法错误只在文件被加载时才暴露。改完任何 `.lua` 至少跑一次：

```bash
resty -e 'assert(loadfile("lua/app.lua"))' && echo "syntax OK"
```

完整的验证与发布门禁见 `.harness/guides/validation-and-release.md`。
