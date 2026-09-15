# OpenResty 审查清单 Guide

审查一律从代码本身出发，不锚在"我这次想改什么"上。刚改完的代码是最高嫌疑对象，
重读整个函数与其调用链，而不是只看新增的那几行。

## 1. 语言与运行时

- [ ] 没有 Lua 5.3/5.4 专属语法（`//`、`&` `|` `<<` `~`、`<const>`、`<close>`）
- [ ] 没有调用 LuaJIT 里不存在的库函数（`string.pack`、`math.type`、`math.tointeger`、`warn`）
- [ ] 每个赋值都有 `local`，没有意外的全局变量
- [ ] 大整数 ID 全链路是字符串，没有中途 `tonumber`
- [ ] 热路径上的 `ngx.*` 与标准库函数已在文件顶部 `local` 化

## 2. 阶段与结构

- [ ] 逻辑放在了最早能完成它的阶段（鉴权在 access，不在 content）
- [ ] `log` / `body_filter` 阶段没有 cosocket IO
- [ ] 单入口脚本形态下，没有把跨请求状态放在顶层 `local`
- [ ] "只初始化一次"的动作在 `init_by_lua`，不在请求路径
- [ ] 顺序 `if` 路由的每个分支都以 `return` 结束
- [ ] 模块顶层没有 IO、没有建连接

## 3. 出站 IO

- [ ] 请求路径上没有阻塞调用（`os.execute`、`io.popen`、LuaSocket、忙等）
- [ ] 每条 return 路径都处理了连接：正常 `set_keepalive`，出错 `close`
- [ ] `set_keepalive` 之后没有再使用该连接对象
- [ ] 连接池大小 × worker 数不超过后端 `max_connections`
- [ ] 认证 / `select db` 用 `get_reused_times()` 判断，或用了独立 pool 名
- [ ] 每一跳超时小于上游剩余预算，超时值是具名常量
- [ ] 失败路径明确定义了返回值、重试策略与可定位的日志

## 4. 共享状态

- [ ] 存进 shared dict 的是 string / number / boolean（table 已 encode）
- [ ] `dict:set` 检查了 `ok` 与 `forcible`
- [ ] `dict:incr` 带了 init 参数
- [ ] 热点 key 有击穿防护，拿锁后二次检查，所有路径都 unlock，锁用独立 dict
- [ ] lrucache 实例在模块顶层创建，且该数据允许 worker 间不一致
- [ ] 只应执行一次的定时任务用 `ngx.worker.id() == 0` 限定

## 5. 数据与编解码

- [ ] 用的是 `cjson.safe`，每个 `decode` 返回值都判断了
- [ ] 需要空数组的字段初始化时就挂了 `empty_array_mt`
- [ ] 必填校验同时排除 `nil`、`cjson.null`、空串
- [ ] Redis 返回值区分了 `ngx.null`（不存在）与 `nil, err`（出错）
- [ ] 进入 SQL 的外部值都过了 `ngx.quote_sql_str`，且没有重复加引号
- [ ] 表名 / 列名 / ORDER BY 字段只来自代码内白名单

## 6. 配置与安全

- [ ] 代码里没有真实密码、token、内网地址字面量
- [ ] 用到的环境变量在 nginx.conf 顶层有 `env` 声明
- [ ] `lua_code_cache off` 没有被带进提交
- [ ] 日志与对外错误信息里没有敏感字段、SQL 原文、内网地址
- [ ] 外部输入在进入正则前有长度限制（防解析炸弹）

## 7. 跨文件契约

- [ ] 新增 / 改名的 shared dict，nginx.conf 与 Lua 两侧同步改了
- [ ] 新 `require` 的模块在 `lua_package_path` 覆盖范围内
- [ ] cosocket 连域名时 `resolver` 已配置
- [ ] `lua/resty/` 等 vendored 目录没有出现在 diff 里（出现了要说明原因）

## 8. 新失败模式回审调用方

每引入一个新的失败模式（新错误返回、新超时、部分成功、新的并发交错），
`grep` 出该函数的全部调用方，逐个确认其错误处理是按**新世界**写的。
旧调用方的错误分支通常是按"要么全成功要么全失败"写的。

- [ ] 改过的函数的调用方已逐个确认
- [ ] 新增的 nil 返回路径在调用方有对应分支

## 9. 验证

- [ ] Lua 语法检查通过
- [ ] `nginx -t` 通过
- [ ] 改动的接口实际发过请求，看到预期响应
- [ ] `error.log` 里本次请求没有 ERR / WARN
- [ ] 跑不了的验证写明了原因，没有跳过不提

## 合规摘要模板

```text
## 合规检查摘要
- [x] Lua 语法检查：<命令> 通过
- [x] nginx -t：通过
- [x] 冒烟：<接口> 实际请求，响应 <结果>
- [x] error.log：本次请求无 ERR / WARN
- [x] 阶段选择、连接回收、超时与失败路径已检查
- [x] 共享状态范围与并发交错已检查
- [x] 新失败模式的调用方已回审
- [x] 无硬编码密钥与调试配置残留
- [x] 无编造内容
```
