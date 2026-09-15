# Error Journal — Agent 错误记忆

> 本文件记录 AI Agent 在本项目中犯过的错误，作为前馈引导防止再犯。
> 未关闭的条目由 SessionStart hook 在会话开始时注入，不需要每次手动通读。
> 新错误追加在文件末尾，不要修改已有条目。

---

<!-- 以下是示例条目，可根据实际情况删除或保留作为参考 -->

## 2026-09-15: [用了 LuaJIT 不支持的语法]

**错误描述**：写了 `local half = total // 2` 和 `bit_flag = a & b`，nginx 加载该文件时报 `unexpected symbol near '/'`
**根因分析**：按 Lua 5.3/5.4 的习惯下笔，没有先确认运行时是 LuaJIT 2.1（Lua 5.1 语义）
**正确做法**：整除用 `math.floor(a / b)`，位运算 `local bit = require "bit"` 后用 `bit.band`；写之前先看 `.harness/guides/lua-baseline.md` 的可用/不可用表
**受影响范围**：所有 `.lua` 文件
**新增验证**：改完跑 `luajit -b <file> /dev/null`

---

## 2026-09-15: [连接没有回收]

**错误描述**：在查询失败的 `return nil, err` 分支里漏掉了连接处理，压测时出现大量 TIME_WAIT 与连接耗尽
**根因分析**：只在正常路径写了 `set_keepalive`，错误路径直接 return 了
**正确做法**：每条 return 路径都要处理连接——正常路径 `set_keepalive`，出错路径 `close`；改完对着函数逐条 return 核对一遍
**受影响范围**：所有使用 `resty.mysql` / `resty.redis` / `resty.http` 的代码
**新增验证**：冒烟请求后 `tail logs/error.log` 确认无连接相关错误

---

<!-- 新错误从这里开始追加 -->
