# Error Journal

> 每次任务开始时 Agent 必须读取此文件。
> 当命中类似错误、用户纠正、测试失败、审查发现问题时，必须追加记录。

## YYYY-MM-DD: [错误类别]

**错误描述**：例如 Laravel Resource 改了字段，但前端 API 类型没有同步。  
**根因分析**：后端和前端契约未做联动检查。  
**正确做法**：后端变更后同步检查 `frontend/src/api/` 类型、错误码和分页结构。  
**受影响范围**：Laravel Resource、前端 API 类型、联调页面。  
**新增验证**：`php artisan test`、`npx vue-tsc --noEmit`、`npm run build`。
