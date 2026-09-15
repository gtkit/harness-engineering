# 配置与密钥 Guide

## 问题形态

OpenResty 项目没有 `.env` 之类的约定入口，默认路径就是把地址和密码写在 Lua 里：

```lua
local red = REDIS:new({host = "172.16.78.100", port = 6379})
...
local reauth = red:auth('office_2020')          -- 同一个密码在文件里出现多次
```

这带来三个具体后果，每一个都会真实发生：切环境要改代码并提交（git 历史里全是
"换测试环境 redis 地址"这类提交）；密码进了版本库，轮换时要改 N 处且一定会漏；
本地调试的地址被误提交上线。

## Nginx 不会把环境变量传给 Lua——除非声明

实测：`nginx.conf` 里没有 `env` 指令时，`os.getenv("HOME")` 返回 **nil**，
即使 shell 里 `HOME` 明明有值。Nginx 启动时会清空环境，每个要用的变量必须显式声明：

```nginx
# nginx.conf 顶层（http 块之外）
env REDIS_HOST;
env REDIS_PORT;
env REDIS_PASSWORD;
env MYSQL_DSN;
```

声明之后实测可读：

```lua
os.getenv("REDIS_PASSWORD")   --> "s3cr3t-from-env"
```

`env` 指令必须写在配置文件顶层，不能放 `http` / `server` 块里。
声明了但启动时没设值的变量，`os.getenv` 同样返回 nil，配置读取要有缺失处理。

## 推荐结构

**一个模块统一读配置，其他地方只 require 它**：

```lua
-- lua/libs/config.lua
local _M = {}

local function env(name, default)
    local v = os.getenv(name)
    if v == nil or v == "" then
        if default == nil then
            error("missing required env: " .. name)     -- 启动期就失败，不拖到请求期
        end
        return default
    end
    return v
end

_M.redis = {
    host     = env("REDIS_HOST", "127.0.0.1"),
    port     = tonumber(env("REDIS_PORT", "6379")),
    password = env("REDIS_PASSWORD"),                   -- 无默认值：必须提供
}

_M.mysql = {
    host     = env("MYSQL_HOST", "127.0.0.1"),
    port     = tonumber(env("MYSQL_PORT", "3306")),
    database = env("MYSQL_DATABASE"),
    user     = env("MYSQL_USER"),
    password = env("MYSQL_PASSWORD"),
}

return _M
```

在 `init_by_lua_block` 里 `require` 一次，让缺配置在**启动时**就报错退出，
而不是等第一个请求进来才 500：

```nginx
init_by_lua_block {
    require "libs.config"
    require("cjson").encode_number_precision(16)
}
```

必填项没有默认值、直接 `error` —— 这比给一个 `"127.0.0.1"` 的默认值安全得多，
后者会让配置错误表现为"连到了错误的库"而不是明确的启动失败。

## 已经硬编码了怎么迁

分两步，不要混在业务改动里：

1. **先收敛**：把散落各处的字面量收进 `libs/config.lua`，值暂时保持原样。
   这一步不改行为，`grep` 能验证：改完之后 `grep -rn "172\.16\|password\s*=" lua/`
   应该只在 config.lua 里有命中。
2. **再外置**：把 config.lua 里的值换成 `env(...)`，同时在 nginx.conf 加 `env` 声明，
   并提供一份 `conf/env.example.sh`（只有变量名和占位符，可以入库）。

密码一旦进过 git 历史，**改代码不等于安全了**——历史里还在。
按顺序处理：先在 Redis / MySQL 侧**吊销并轮换该密码**，再清理代码，
必要时用 `git filter-repo` 清历史。轮换优先于清历史，反过来做等于裸奔期间还在浪费时间。

## 禁止入库

- 真实密码、token、密钥、私钥，无论写在 `.lua`、`.conf` 还是 shell 脚本里
- `logs/` 下的运行日志
- 带真实内网地址与账号的 `nginx.conf`（模板化：用 `env` 或 include 一份不入库的片段）

可以入库的是：变量名清单与占位符示例、本地默认值（`127.0.0.1` + 开发账号）、
`conf/nginx.conf` 模板本身。

## 日志脱敏

`ngx.log` 打出来的内容会进 `error.log`，日志文件往往比代码传播得更广：

- 不打完整 token / 密码 / 身份证 / 手机号，需要定位时打前后各 4 位
- 不整体 `cjson.encode(body)` 打印请求体——里面什么都有
- 返回给客户端的错误信息不带 SQL 原文、内网地址、堆栈

## 检查项

- [ ] 代码里没有真实密码、token、内网地址字面量
- [ ] 每个用到的环境变量在 nginx.conf 顶层有 `env` 声明
- [ ] 配置集中在一个模块，必填项缺失时启动就报错
- [ ] `init_by_lua` 里 require 过配置模块，配置错误不会拖到请求期
- [ ] 提供了变量名占位示例文件，真实值不入库
- [ ] 曾经入库的密钥已经吊销轮换，不是只从代码里删掉
- [ ] 日志与对外错误信息里没有敏感字段
