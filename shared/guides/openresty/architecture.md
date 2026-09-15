# OpenResty 结构与阶段 Guide

## 先确认这个项目是哪种形态

动手前先读 `conf/nginx.conf`（或 `conf/` 下被 include 的片段），确认 Lua 是怎么挂进 Nginx 的：

| 挂载方式 | 形态 | 代码组织后果 |
| --- | --- | --- |
| `content_by_lua_file ./lua/app.lua` | 单入口脚本 | app.lua 的**整个 chunk 每个请求执行一次** |
| `content_by_lua_block { require("app").run() }` | 模块化 | 模块只 `require` 一次，之后每请求只调函数 |
| `access_by_lua_file` / `rewrite_by_lua_file` | 拦截层（WAF / 鉴权 / 签名） | 只做判定与放行，不产出响应体 |
| `init_by_lua_block` | 启动期 | master 进程执行，产物被所有 worker 继承 |
| `init_worker_by_lua_block` | worker 启动期 | 每个 worker 各跑一次，定时器在这里起 |

这个判断决定了所有后续写法，先确认再动手，不要假设。

## 单入口脚本形态的关键约束

`content_by_lua_file` 指向的文件，**每个请求都会从第一行执行到最后一行**。
`lua_code_cache on` 缓存的是编译结果（省去每次解析），不是执行结果。所以：

```lua
-- app.lua 顶部
local red = REDIS:new({host = "...", port = 6379})   -- 每个请求都新建一次
```

这一行不是"全局只建一次"，它是每请求一次。实测对比（`lua_code_cache on`，连打 3 次请求）：

```lua
-- content_by_lua_file 指向的 counter.lua
local counter = 0
counter = counter + 1
ngx.say("counter=", counter)     --> 三次都是 counter=1
```

```lua
-- 被 require 的模块 modcount.lua
local counter = 0                 -- 模块只加载一次
function _M.run() counter = counter + 1; ngx.say("counter=", counter) end
                                  --> 三次分别是 1、2、3
```

同一次测试里 `ngx.shared.st:incr("reqs", 1, 0)` 正常累加到 3，证明确实处理了三个请求。
在这种形态下：

- 顶层 `local` 只是本次请求的局部变量，**不能用来做跨请求缓存**
- 需要跨请求共享的数据走 `lua_shared_dict` 或 `lua-resty-lrucache`，见
  `.harness/guides/shared-state.md`
- 需要"只初始化一次"的动作（`cjson.encode_number_precision`、预编译正则、加载配置）
  放 `init_by_lua_block`，不要放 app.lua 顶部
- 路由用一串 `if ngx.var.request_uri == "/path" then ... end` 顺序匹配时，
  每个分支必须以 `return` 结束（`return ngx.say(...)` 或 `return ngx.exit(...)`），
  否则会继续往下比对后面所有分支

新增接口时匹配既有风格：现有代码是顺序 `if` 就继续用顺序 `if`，不要顺手改成 table 路由表——
那是独立的重构，需要单独提出来讨论，不能夹带在功能改动里。

## 阶段选择

按"这段逻辑最早能在哪个阶段做完"来选，越早拦截越省资源：

- **rewrite**：URI 改写、跳转
- **access**：鉴权、签名校验、IP 黑白名单、限流。拒绝请求用 `ngx.exit(ngx.HTTP_FORBIDDEN)`
- **content**：产出响应体。一个 location 只能有一个 content 阶段处理器
- **header_filter / body_filter**：改响应头 / 响应体。**body_filter 里不能做任何 cosocket IO**
- **log**：记日志、上报。同样不能做 cosocket IO，耗时操作丢给 `ngx.timer.at(0, ...)`
- **init_worker**：起定时任务、预热缓存

`ngx.ctx` 用于跨阶段传数据（access 阶段算出的用户身份传给 content 阶段）。它是每请求一张新表，
创建有成本，不要把它当通用命名空间往里塞几十个字段。内部重定向（`ngx.exec`）会重置 `ngx.ctx`。

各阶段可用 API 的完整清单和边界行为，`openresty-patterns` 与 `senior-openresty-engineer`
两个 skill 里有；本 guide 只定本仓库的组织约定。

## 目录与模块边界

```text
conf/nginx.conf          ← Nginx 配置与 Lua 挂载点，改动需 nginx -t
lua/app.lua              ← 请求入口
lua/libs/                ← 本项目自己的模块（db / redis / utils / common）
lua/resty/               ← 第三方 lua-resty-* 库（vendored，见 vendor-and-deps.md）
```

- `lua/libs/` 下的模块返回一个 table，不写全局变量。`local _M = {}` ... `return _M`
- 模块顶层不做 IO、不建连接、不读文件——模块可能在 `init_by_lua` 阶段被 require，
  那个阶段没有 cosocket
- 模块之间不循环 require
- 业务判断不要写进 `lua/libs/db.lua` 这类基础模块，那里只放连接管理和查询执行

## 全局变量禁令

OpenResty 里写全局变量（漏写 `local`）有两个后果：Lua VM 是 per-worker 的，全局变量在同一个
worker 处理的请求间残留，形成跨请求污染；同时 `lua_code_cache on` 下这种污染会一直存在到 reload。

每个 `.lua` 文件的每个赋值都要有 `local`。`lua/` 下的文件可以用 `resty -e` 跑
`setmetatable(_G, {__newindex = function() error("global write") end})` 之类的守卫做一次性核查，
但更可靠的是 luacheck（见 `.harness/guides/validation-and-release.md`）。

## 检查项

- [ ] 改动前确认了 Lua 的挂载方式（单入口脚本 / 模块 / 拦截层）
- [ ] 顺序 `if` 路由的每个分支都以 `return` 结束
- [ ] 没有把跨请求状态放在单入口脚本的顶层 `local` 里
- [ ] "只做一次"的初始化在 `init_by_lua`，不在请求路径上
- [ ] 模块顶层没有 IO 和连接创建
- [ ] 没有漏写 `local` 的全局变量
- [ ] log / body_filter 阶段没有 cosocket 调用
