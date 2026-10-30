# TypeScript MCP npm 分发

本包用于 TypeScript 服务，运行/安装链不添加 Go 或 Go 编译。按需求选择 npm 包、已有运行时部署或宿主插件配置；无需同时实现多种交付方式。

## npm 产物与执行入口

- 核对 package 的 `bin`、`files`、`exports`、`type`、`engines` 与实际发布内容。bin 指向真实可执行入口，Node 脚本保留正确 shebang；包内路径以模块/包位置定位，不依赖调用方 cwd。[npm package.json](https://docs.npmjs.com/cli/v11/configuring-npm/package-json/)
- 发布可在声明运行时执行的 JS；若明确选择 TS loader，保证运行时依赖和宿主可用。开发环境能跑 `.ts` 不代表 npm 安装后可跑，不能依赖 devDependencies 或隐式下载 tsx/ts-node。
- 核对 ESM/CJS、动态导入、扩展名、资源文件和生产依赖；类型声明与 source map 按实际用途发布，包内不含秘密、测试私有数据或真实本机路径。
- 明确包版本、dist-tag、SDK/运行时兼容范围与宿主命令。不能将 `latest` 当固定版本验收；npm/npx、直接入口与宿主启动分别记录证据。
- 安装脚本确有需要才添加；说明禁用 lifecycle scripts、离线、代理、只读目录及缺少原生依赖的行为。安装器不修改全局客户端配置，不在启动时静默下载执行代码。

## 运行与远程部署

stdout 保持协议纯净，日志 stderr；包装器正确传播参数、env、信号和退出码。下载外部资源须核实来源、完整性/真实性、平台和许可，失败不得继续执行。

远程 HTTP 交付写明 URL/TLS、授权、协议/SDK 版本、代理、流式限制、容量和回滚。宿主 manifest 与 env 展开规则按其官方格式核实，不复制另一客户端配置。

## 验收与版本

获准打包/安装时检查实际 tarball 和运行入口，不能以源码测试替代发布产物验证。全过程在用户允许的原项目与资源范围内，不创建项目副本；没有获准条件就保留未验证。

CHANGELOG、package 版本、资产/插件清单/tag 同步，评估工具契约与持久格式兼容。未经明确授权不首次升应用 v2，不因 SDK v2 推动项目升主版本。准备可审阅内容后按授权安装、部署或发布；失败保护已有版本、用户配置和数据。
