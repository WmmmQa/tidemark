# Mooncakes 发布前清单

此清单用于准备未来的公开包发布；项目尚未发布到 Mooncakes。

## 发布前

- [ ] 确认 `moon.mod` 的模块名、仓库地址、许可证和说明与 GitHub 仓库一致。
- [ ] 按语义化版本规则更新 `moon.mod`：增加向后兼容功能时提升次版本；破坏公开 API 时提升主版本。
- [ ] 在干净工作区运行 `moon fmt`、`moon info`、`moon check --target native --deny-warn`、`moon test --target native --deny-warn`、`moon test --target js --deny-warn` 及 `node scripts/check-examples.mjs native` / `js`，并核对原有两个演示。
- [ ] 检查生成的 `pkg.generated.mbti` 与当前公开 API 一致，并审阅 README 和本清单中的范围边界。
- [ ] 在 Mooncakes 账号上完成注册或登录，并确认账号有权代表模块所有者发布。

## 发布

- [ ] 在本机运行 `moon publish` 并按 MoonBit CLI 提示完成发布。
- [ ] 只通过 MoonBit CLI 管理发布凭据；不要将凭据文件、令牌或环境变量值提交到 Git。
- [ ] 发布后打开 Mooncakes 模块页面，核对版本、源码链接和可见 API。
- [ ] 将发布版本与对应 Git 提交关联，记录真实发布日期和版本号。

若 Mooncakes 账号、模块归属或发布状态不明确，先由仓库所有者确认再发布。
