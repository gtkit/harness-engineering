# Validation Standard

## 最低必需项

1. clang-format
2. clang-tidy
3. cppcheck
4. GCC / Clang 至少主线构建
5. Debug / Release
6. 单元测试
7. 集成测试
8. 端到端 smoke
9. ASan / UBSan / TSan / LSan
10. benchmark smoke
11. Linux 启动 / 停止 / 健康检查
12. AI 加载 / 错误制品 / 超时 / 并发专项验证

## 结论约束

无以下证据，不得宣称对应结论：

- 无 TSan：不得宣称线程安全
- 无 LSan：不得宣称无泄漏
- 无 Release benchmark：不得宣称性能达标
- 无启动 / 停止验证：不得宣称可部署
- 无 AI smoke：不得宣称模型接入可用

## 未执行项处理

未执行项必须标注：

1. 未执行原因
2. 风险影响
3. 是否阻断
4. 责任人
5. 补做计划
