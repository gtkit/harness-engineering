# JSON 与数据编解码 Guide

本篇的所有行为都在 OpenResty 1.27.1.2 自带的 `lua-cjson` 上实测得到。cjson 的几个默认值
和 Lua 表模型的特点叠在一起，会安静地改写响应数据——**不报错，只是值变了**，是这类项目
线上问题最集中的地方。

## 一律用 cjson.safe

```lua
local cjson = require "cjson.safe"
```

`cjson` 与 `cjson.safe` 是同一份实现的两种错误风格，实测差异：

```lua
require("cjson").decode("{bad")      --> 抛错 Expected object key string but found invalid token
require("cjson.safe").decode("{bad") --> nil
require("cjson").encode({x = 1/0})   --> 抛错 Cannot serialise number: must not be NaN or Infinity
require("cjson.safe").encode({x=1/0})--> nil
```

请求体来自客户端，永远可能是坏数据。用 `cjson.safe` 并**检查返回值**：

```lua
local body, err = cjson.decode(json_str)
if not body then
    ngx_log(ngx_ERR, "decode request body failed: ", err)
    return ngx.exit(ngx.HTTP_BAD_REQUEST)
end
```

`local body = cjson.decode(s)` 之后直接 `body.foo` 是本类项目里最常见的 500 来源：
解码失败时 `body` 是 nil，下一行就是 `attempt to index a nil value`。

## 数字精度：默认会丢

cjson 默认 `encode_number_precision` 是 **14 位有效数字**。实测：

```lua
cjson.encode({id = 1000000000000001})  --> {"id":1e+15}            ← 值已经没了
cjson.encode({id = 2^53})              --> {"id":9.007199254741e+15} ← 科学计数法，客户端解析报错
```

即 10^15 量级的订单号在默认配置下直接变成 `1e+15`。两条应对，按顺序优先：

1. **大整数标识用字符串贯穿全链路**（首选）。从 MySQL 查询时就 `CAST(id AS CHAR)`，
   Redis 里存字符串，Lua 里不做 `tonumber`，响应里是 `"id":"1000000000000001"`。
   这条同时解决了 JS 客户端 `Number.MAX_SAFE_INTEGER` 的问题。
2. 确实必须是 JSON number 时，在 `init_by_lua` 阶段全局设一次：

   ```lua
   require("cjson").encode_number_precision(16)
   ```

   实测 `precision = 16` 下 `{"id":1000000000000001}` 和 `{"id":9007199254740992}` 都正确。
   上限就是 16（传 17 报 `bad argument #1 to '?' (expected integer between 1 and 16)`），
   而且 double 本身在 2^53 以上无法区分相邻整数，所以这只是把安全区间抬到 2^53，不是根治。

decode 方向同样有损：`cjson.decode('{"id":9007199254740993}')` 得到的是 9007199254740992。
**转发第三方 JSON 时不要 decode 再 encode**，需要原样透传就传原始字符串。

## 空表是 `{}` 不是 `[]`

Lua 只有一种 table，cjson 无法区分空对象和空数组，实测默认编码成 `{}`：

```lua
cjson.encode({})  --> {}
```

列表字段为空时客户端拿到 `{}` 而不是 `[]`，弱类型客户端会静默走错分支。需要空数组时显式标注：

```lua
local cjson = require "cjson.safe"

local list = setmetatable({}, cjson.empty_array_mt)
cjson.encode({data = list})  --> {"data":[]}
```

（`cjson.safe` 同样暴露 `empty_array_mt` 与 `null`，不需要再单独 require 非 safe 版。）

约定：**任何返回列表的接口，列表变量在初始化时就挂上 `empty_array_mt`**，而不是在填充完
判断长度再补。后者一定会漏。

## 稀疏表会被填 null

```lua
cjson.encode({[1] = 1, [3] = 3})  --> [1,null,3]
```

从查询结果拼数组时用 `#t + 1` 或独立计数器递增下标，不要用业务 ID 当下标。

## null 的三种身份

```lua
local d = cjson.decode('{"a":null}')
d.a == cjson.null   --> true     （userdata: NULL）
d.a == ngx.null     --> true     （同一个 userdata）
d.a == nil          --> false    ← 注意
```

JSON 里的 `null` 解码后是 userdata，不是 nil，`if d.a then` 判断为**真**。
校验必填字段时要同时排除两者：

```lua
if body.token == nil or body.token == cjson.null or body.token == "" then
```

`ngx.null` 还会从 `resty.redis` 的查询结果里返回（表示 key 不存在），判断方式相同。

## 与 Redis / MySQL 的边界

- `resty.redis` 的返回值：key 不存在是 `ngx.null`，命令出错是 `nil, err`。两者必须分开判断，
  `if not res then` 会把"key 不存在"漏进错误分支。
- `resty.mysql` 的查询结果里，`NULL` 列同样是 `ngx.null`；`DECIMAL` 返回字符串，
  直接参与算术会变成 double，金额计算不要 `tonumber` 后再算。
- 存进 Redis 的结构化数据统一用 `cjson.encode`，取出后 `cjson.safe.decode` 并检查返回值——
  Redis 里可能存着上一个版本写入的旧格式。

## 检查项

- [ ] 用的是 `cjson.safe`，并且每个 `decode` 的返回值都判断了
- [ ] 大整数 ID 全链路是字符串，没有中途 `tonumber`
- [ ] 需要空数组的字段初始化时就挂了 `empty_array_mt`
- [ ] 数组下标连续，没有用业务 ID 当下标
- [ ] 必填字段校验同时排除了 `nil`、`cjson.null` 和空串
- [ ] Redis 返回值区分了 `ngx.null`（不存在）与 `nil, err`（出错）
