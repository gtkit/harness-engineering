# Build and Toolchain Guide

## 基线

1. 构建系统统一使用 `CMake`
2. 编译器矩阵至少覆盖 `GCC` 与 `Clang`
3. 默认支持 `Debug` 与 `Release`
4. 额外质量构建至少覆盖：
   - `ASan`
   - `UBSan`
   - `TSan`
   - `LSan`
5. 所有测试统一通过 `CTest` 接入或提供等价统一入口

## 必备产物

1. `compile_commands.json`
2. 可重现构建配置
3. 构建日志
4. 测试日志
5. 静态检查日志
6. 发布构建产物
7. 版本信息与构建信息

## 编译器要求

1. GCC 版本：`需用户补充`
2. Clang 版本：`需用户补充`
3. 统一固定最低版本，不允许 CI 与生产使用不兼容版本
4. 编译器版本升级必须走兼容性验证

## 标准构建要求

1. 默认启用高等级告警
2. CI 中默认 `-Werror`
3. 启用调试符号策略
4. Release 构建禁止带未审查调试选项
5. 编译选项必须区分：
   - 开发调试
   - 生产发布
   - Sanitizer
   - 性能分析

## 参考命令

```bash
cmake -S . -B build/debug -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_STANDARD=20
cmake --build build/debug -j
ctest --test-dir build/debug --output-on-failure
```

```bash
cmake -S . -B build/release -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=23
cmake --build build/release -j
ctest --test-dir build/release --output-on-failure
```

如项目只固定一种标准，`20/23` 由项目显式指定。

## 静态检查

1. `clang-format`
2. `clang-tidy`
3. `cppcheck`

静态检查必须满足：

1. 规则集固定
2. 版本固定
3. 输出可追溯
4. 抑制项必须带理由
5. 新增抑制项必须审查

## 依赖管理

1. 所有依赖必须固定版本
2. 不允许直接依赖分支 HEAD
3. 第三方依赖来源必须可追溯
4. 二进制依赖、模型运行时依赖、系统包依赖必须单独记录
5. 依赖管理工具：`需用户补充`

## CMake 组织要求

1. 模块化 `CMakeLists.txt`
2. 公共编译选项统一管理
3. 公共告警统一管理
4. 公共 Sanitizer 选项统一管理
5. 目标级别链接依赖显式声明
6. 不允许全局污染编译选项
7. 测试、benchmark、工具目标显式分组

## CI 最低门槛

至少包含以下流水线或等价流程：

1. 格式化检查
2. GCC Debug 构建 + 测试
3. GCC Release 构建 + 测试
4. Clang Debug 构建 + 测试
5. Clang ASan + UBSan
6. Clang TSan
7. cppcheck
8. benchmark smoke
9. 打包 / 安装 / 启动 smoke

## 可重现与可追溯

1. 记录 commit id
2. 记录编译器版本
3. 记录依赖版本
4. 记录构建时间
5. 记录构建选项
6. 生产事故必须能回溯到构建信息

## 发布要求

1. Release 产物必须来自干净构建
2. Release 产物必须经过对应测试矩阵
3. 产物签名、校验、制品仓库存放方式：`需用户补充`
4. 不允许手工替换构建产物绕过流程
