# nginx.conf 与 Lua 的契约 Guide

`conf/nginx.conf` 和 `lua/` 下的代码是一份跨文件契约的两半。只改一半，错误在启动或首次请求时
才暴露。**每次改 Lua 都要回头确认 nginx.conf 这边是否也要改，反之亦然。**

## 必须成对改的四类

| nginx.conf 一侧 | Lua 一侧 | 只改一半的后果 |
| --- | --- | --- |
| `lua_shared_dict NAME SIZE;` | `ngx.shared.NAME` | Lua 侧拿到 nil，`attempt to index a nil value` |
| `lua_package_path` | `require "libs.xxx"` | `module 'libs.xxx' not found`，报错里会列出搜索过的全部路径 |
| `resolver 8.8.8.8;` | cosocket 连域名 | 连接报 `no resolver defined to resolve "xxx"` |
| `location` 的 `content_by_lua_file` | 新增接口路径 | 请求 404，或落到别的 location |

新增一个 shared dict 时，在 nginx.conf 里声明和在 Lua 里使用必须在同一次改动里完成，
容量怎么定见 `.harness/guides/shared-state.md`。

## `lua_code_cache` 的两面

```nginx
lua_code_cache off;   # 开发：改完 Lua 刷新页面即生效，不用 reload
lua_code_cache on;    # 线上：必须
```

`off` 时每个请求重新加载所有 Lua 模块，性能是数量级的差距，而且模块级状态（包括
lrucache、连接池的 Lua 侧包装）每次请求都重建，行为和线上完全不同。

**这一行的当前值属于环境差异，不是代码改动的一部分。** 本地为了调试改成 `off` 之后，
提交前必须确认没有把它带进 diff。仓库里如果这一行带着 `# 上线时要改为 on` 之类的注释，
说明它曾经被误提交过——改动这个文件时优先确认当前值是否正确。

## 超时与体积限制

Nginx 层的限制会先于 Lua 生效，Lua 里的超时设置必须小于它们，否则 Lua 的错误处理根本没机会跑：

```nginx
client_body_buffer_size 128k;   # 超过这个值请求体落盘，ngx.req.get_body_data() 返回 nil
client_max_body_size    10m;    # 超过直接 413，Lua 不会被执行
send_timeout            60s;
lua_socket_connect_timeout / lua_socket_send_timeout / lua_socket_read_timeout
```

`ngx.req.get_body_data()` 返回 nil 有两种原因：没调 `ngx.req.read_body()`，
或请求体大于 `client_body_buffer_size` 已落到临时文件。后者要用
`ngx.req.get_body_file()` 读。**处理可能较大的请求体时两种情况都要覆盖。**

## 日志

- `error_log` 的级别决定 `ngx.log(ngx.DEBUG, ...)` 是否可见，排查问题前先确认当前级别
- 访问日志的 `log_format` 里如果引用了 `$request_time` 之外的变量，确认那些变量在 Lua 里被赋值过
- Lua 里 `ngx.log` 的第一个参数用 `ngx.ERR` / `ngx.WARN` / `ngx.INFO`，不要用字符串

## 改完必须验证

```bash
nginx -t -p . -c conf/nginx.conf      # 语法与路径检查，不通过就不算改完
```

这一步在本类项目里的地位等同于编译。`nginx -t` 通过之后才谈得上跑起来验证，
完整门禁见 `.harness/guides/validation-and-release.md`。

注意 `nginx -t` 只检查 Nginx 配置语法，**不检查 `*_by_lua_file` 指向的文件是否存在或能否解析**——
Lua 文件的语法要单独验。`*_by_lua_block` 里的内联 Lua 则会在 `nginx -t` 时被解析，
这是把 Lua 写进 block 的一个优势。

## 检查项

- [ ] 新增 / 改名 shared dict 时，nginx.conf 与 Lua 两侧在同一次改动里同步
- [ ] 新增 `require` 的模块路径在 `lua_package_path` 覆盖范围内
- [ ] cosocket 连域名时 `resolver` 已配置
- [ ] `lua_code_cache` 没有被调试值带进提交
- [ ] Lua 侧超时小于 Nginx 层超时
- [ ] 请求体处理覆盖了落盘的情况
- [ ] `nginx -t` 通过
