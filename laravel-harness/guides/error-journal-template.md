# Error Journal

> 每次任务开始时 Agent 必须读取此文件。
> 当命中类似错误、用户纠正、测试失败、审查发现问题时，必须追加记录。

## YYYY-MM-DD: [错误类别]

**错误描述**：例如在 Controller 中直接写事务和通知发送，导致职责混乱。  
**根因分析**：未按 Controller / Service / Notification 分层处理。  
**正确做法**：事务与业务编排下沉到 Service，通知独立为 Notification / Mail 类，并补验证。  
**受影响范围**：相关 Controller、Service、Queue Job、Notification。  
**新增验证**：`php artisan test` / 指定 Feature 或 Integration 测试。
