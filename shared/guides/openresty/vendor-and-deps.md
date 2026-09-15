# 第三方库与依赖 Guide

## 三个来源，处理方式不同

OpenResty 项目里的 Lua 模块有三个来源，改动前先确认手上这个文件属于哪一类：

| 来源 | 典型路径 | 能不能改 |
| --- | --- | --- |
| OpenResty 自带 | `/usr/local/openresty/lualib/resty/*` | 不改，也不要复制一份到项目里覆盖 |
| vendored 第三方库 | `lua/resty/*`、`lua/vendor/*` | **不改**，见下 |
| 本项目代码 | `lua/app.lua`、`lua/libs/*` | 本次任务范围内可改 |

`resty.redis`、`resty.mysql`、`resty.core`、`resty.lrucache`、`resty.lock` 这些是
OpenResty **自带**的，不需要也不应该在项目里再放一份。项目 `lua/resty/` 下常见的是
自带之外的库：`resty.jwt`、`resty.http`、`resty.cookie`、`resty.hmac`、`resty.requests` 等。

## vendored 库的纪律

`lua/resty/` 下的文件是别人的代码，按外部依赖对待：

- **不修改。** 需要改行为时，在 `lua/libs/` 下写一层包装，不要动库文件本身。
  直接改了，下次升级库就会把你的改动覆盖掉，而且没有任何记录说明那里曾经改过。
- **不重构、不格式化。** 它不符合本项目的代码风格是正常的。
- **不纳入 lint 与语法检查的失败判定。** 检查命令一律带 `-not -path '*/resty/*'`。
- **审查时跳过。** 看 diff 时 `lua/resty/` 下有改动，第一反应是"为什么会动到这里"，
  而不是去审里面的代码。

确实必须改（上游有 bug 且无法绕开）时，三件事一起做：在文件顶部注释里写明
**改了什么、为什么、对应上游哪个版本**；在 README 或依赖清单里记一笔；
把改动限制在最小范围，不顺手整理周边。

## 引入新库前

1. **确认 OpenResty 自带的解决不了。** 先看 `ls /usr/local/openresty/lualib/resty/`。
2. **确认它是非阻塞的。** 看源码里用的是 `ngx.socket` 还是 LuaSocket 的 `socket`。
   用后者的库放进请求路径会阻塞整个 worker——库名叫 `lua-resty-*` 不是证据。
3. **确认它在 LuaJIT 2.1 上能跑。** 用了 `//`、位运算符、`<const>` 等 Lua 5.3/5.4 语法的库
   会直接解析失败，见 `.harness/guides/lua-baseline.md`。
4. **记录版本与来源。** 复制进 `lua/resty/` 时，在依赖清单里写明库名、版本、来源 URL。
   没有这个记录，半年后没人知道这份代码是哪来的、能不能升。

引入新依赖属于会长期留下影响的决定，**先向用户说明再做**，不要在实现功能时顺手引入。

## 模块路径

```nginx
lua_package_path '$prefix/lua/?.lua;;';
```

`$prefix` 由 `nginx -p` 决定，末尾的 `;;` 表示追加默认搜索路径（OpenResty 自带库靠它找到）。
**不要删掉 `;;`**，删了之后 `require "resty.redis"` 会找不到。

新增子目录（如 `lua/libs/http/`）不需要改这一行，`libs.http.client` 会被
`$prefix/lua/libs/http/client.lua` 匹配到。需要加载 `.so` 时才动 `lua_package_cpath`。

`require` 失败的报错会列出它搜索过的全部路径，照着看就知道是路径没配还是文件名不对。

## 检查项

- [ ] 确认了改动的文件属于哪一类来源
- [ ] `lua/resty/` 等 vendored 目录没有出现在本次 diff 里（出现了要说明原因）
- [ ] 语法检查与 lint 命令排除了 vendored 目录
- [ ] 新引入的库确认过非阻塞、确认过 LuaJIT 2.1 兼容、记录了版本来源
- [ ] 引入新依赖前向用户说明过
- [ ] `lua_package_path` 末尾的 `;;` 完好
