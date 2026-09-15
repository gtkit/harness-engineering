# 验证与发布 Guide

## 这里没有编译期

Go 有 `go build`，PHP 有 `php -l`，OpenResty 项目两样都没有：Lua 是运行时加载的，
`nginx -t` 又不检查 `*_by_lua_file` 指向的文件。**一个拼错的变量名可以一路平安到线上，
在某个分支第一次被走到时变成 500。**

所以本类项目的"完成"标准必须由下面这条链条替代编译，四步缺一不可：

```text
1. Lua 语法检查      →  每个改过的 .lua 都能被加载
2. nginx -t          →  配置语法与路径正确
3. 起实例 + 冒烟     →  改过的接口实际发过请求，看到预期响应
4. 看 error.log      →  这次请求没有留下 ERR / WARN
```

只做前两步就说"改完了"是不成立的——语法对不代表逻辑跑得通，本类项目的绝大多数故障
都是运行期的 nil 索引，语法检查一个都拦不住。

## 第 1 步：Lua 语法检查

单个文件：

```bash
luajit -b lua/app.lua /dev/null && echo "syntax OK"
```

（`luajit` 通常在 `$(dirname $(which openresty))/../luajit/bin/luajit`；
也可以用 `resty -e 'assert(loadfile("lua/app.lua"))'`，两者报错信息一致。）

全项目批量。注意 **`find -exec` 的退出码不可靠**——实测单个文件语法错误时
`find ... -exec luajit -b {} /dev/null \;` 整体仍然返回 0，用它当门禁等于没有门禁：

```sh
#!/bin/sh
set -e
LUAJIT="${LUAJIT:-luajit}"
list="$(mktemp)"
find "${1:-lua}" -name '*.lua' -not -path '*/resty/*' > "$list"
fail=0
while IFS= read -r f; do
    "$LUAJIT" -b "$f" /dev/null || fail=1
done < "$list"
rm -f "$list"
[ "$fail" -eq 0 ] || { echo "✗ Lua 语法检查未通过"; exit 1; }
echo "✓ Lua 语法检查通过"
```

`-not -path '*/resty/*'` 跳过 vendored 的第三方库（见
`.harness/guides/vendor-and-deps.md`），只检查自己的代码。

语法检查拦不住的：拼错的变量名（Lua 里读未定义变量是 nil，不是错误）、
漏写的 `local`、类型不匹配。这些交给下一层。

## 第 1.5 步：luacheck（项目已有时必跑）

`luacheck` 能静态抓到语法检查抓不到的那一类问题——未定义的全局变量、漏写 `local`、
未使用的变量、变量遮蔽。项目根有 `.luacheckrc` 时说明已接入，改完必跑：

```bash
luacheck lua/ --exclude-files 'lua/resty/*'
```

`.luacheckrc` 里要声明 OpenResty 的全局符号，否则满屏 `ngx` 未定义的噪音：

```lua
std = "luajit"
globals = { "ngx" }
exclude_files = { "lua/resty/*" }
```

项目没有装 luacheck 时不要擅自加进构建流程，跑一次临时检查即可；
是否常驻由用户决定。

## 第 2 步：nginx -t

```bash
nginx -t -p . -c conf/nginx.conf
```

`-p` 是 prefix，决定 `$prefix`、相对路径和 `logs/` 的解析基准，**必须显式传**，
否则检查的是系统默认安装位置的配置。

这一步通过 = 配置语法正确、所有 `include` 的文件存在、所有指令拼写正确。
它不检查 `content_by_lua_file` 指向的文件是否存在（那要等第一个请求），
但会解析 `*_by_lua_block` 里的内联 Lua。

## 第 3 步：起实例冒烟

改了接口就要发请求，这是本 harness 的默认完成标准，不是可选项。

```bash
nginx -p "$PWD" -c conf/nginx.conf            # 起（daemon on 时会后台驻留）
curl -sS -i http://127.0.0.1:<port>/your/path -d '...'
nginx -p "$PWD" -c conf/nginx.conf -s stop    # 停
```

三条纪律：

- **起完必须停。** 停完用 `pgrep -f "$PWD"` 确认进程真的没了，
  不要把"执行过 stop 命令"当成已经停掉的证据。
- **只连本机已有的依赖。** 需要 Redis / MySQL 时先 `docker ps` 看本机跑着什么，
  复用现有容器；本机没有就停下来问用户，不擅自 `docker pull` / `docker run`。
- **不连生产。** 冒烟用的配置指向本地或测试依赖，验证完不要把这份配置提交。

项目自带 `start.sh` / `stop.sh` / `reload.sh` 时优先用项目脚本，不要另起一套。

## 第 4 步：读 error.log

```bash
tail -n 50 logs/error.log
```

冒烟请求发完，日志里不应有本次产生的 `[error]` / `[warn]`。
Lua 的运行期错误（nil 索引、调用 nil 值）**不会让请求失败得很明显**——
Nginx 返回 500，具体原因只在 error.log 里。
只看 curl 的输出不看日志，等于放过了一半的信息。

## reload 与发布

```bash
nginx -p "$PWD" -c conf/nginx.conf -s reload
```

`reload` 会用新配置起新 worker、让老 worker 处理完手上的请求后退出，对在途请求是平滑的。
但要清楚它的边界：

- `lua_shared_dict` 的内容在 reload 后**保留**（实测：reload 前写入的值，reload 后仍读得到）。
  但这只在该 dict 的名字与大小都没变时成立——**改了 `lua_shared_dict` 的大小或名字，
  那块共享内存会重新分配，里面的限流计数、缓存、幂等标记全部归零**。调整 dict 容量属于
  会丢数据的改动，要按这个前提评估影响。
- `init_by_lua` 会重新执行。
- 老 worker 上挂着的 `ngx.timer` 任务随老 worker 退出而终止。
- **reload 前必须先 `nginx -t` 通过**。配置有错时 reload 会失败并保持旧配置运行
  （不至于挂掉），但会在日志里留下错误，且你以为已经生效了。

修改 `worker_processes`、`listen` 端口这类需要重新绑定的配置时，reload 不够，
需要完整重启——这属于会中断服务的操作，由用户决定时机。

## 提交前自检

```bash
git status                       # 确认没有把调试配置、日志、临时文件带进去
git diff                         # 逐行问"这一行为什么存在"
grep -rn "lua_code_cache off" conf/     # 调试值没带进提交
grep -rn "ngx.log(ngx.DEBUG" lua/       # 临时调试日志已清理
```

特别检查这三样是否被误带入：`lua_code_cache off`、指向本地/测试环境的地址、
为排查加的 print / 调试日志。

## 合规摘要模板

多文件改动或走 `/harness-review` 时附上：

```text
## 合规检查摘要
- [x] Lua 语法检查：<命令> 通过
- [x] nginx -t：通过
- [x] 冒烟：<接口> 实际请求，响应 <结果>
- [x] error.log：本次请求无 ERR / WARN
- [x] 连接回收、超时、失败路径已检查
- [x] 无硬编码密钥与调试配置残留
- [x] 无编造内容
```

跑不了的步骤写明原因（例如"本机无该 MySQL 实例，未做冒烟"），不要跳过不提。
