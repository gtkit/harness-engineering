# Laravel Notification 与 Mail Guide

## 基本规则

- 通知与邮件必须独立建类
- 重通知量或慢渠道默认考虑队列化
- 文案、模板变量、收件人决策不要散落在 Controller / Service 里

## Notification

- 明确渠道：mail / database / broadcast / slack 等
- 渠道选择逻辑应可测试
- 避免在通知类中直接写复杂业务查询

## Mail

- `Mailable` 负责模板与渲染
- 敏感信息最小化进入邮件与日志
- 大附件、外部下载链接等高风险路径需要额外审查

## 审查重点

- 是否误把同步通知放在热路径
- 是否在失败重试时造成重复发送
- 是否泄漏 token、URL 签名、隐私字段
