# 十一月初审自查

## 申报范围

十月评审指出，原方案与生态已有求解器相比，独立核心贡献不足。此次保留十月基线 `5fcf3ea`，把申报对象限定为本期开发的整数公式运行时。核心源码集中在 `worksheet/`，含文本解析、依赖链接与调度、检查型整数求值和快照更新。它可以独立引入，无需优化器、财务模型或 CLI。预算对账和表计守恒使用同一套公开 API。

官网十一月页面要求提交公开仓库和一页项目说明，允许已有项目以本期可追溯的实质贡献参赛。飞书章程链接会跳转登录，已公开内容尚不足以确认十月未过审的同一仓库能否按表单的「新项目」类别申报，也未给出具体截止日。申报书明确写出仓库历史和本期新模块，填表前以组委会口径为准。[十一月官网](https://moonbitlang.github.io/Hackathon2026/#process) · [官网十一月更新](https://github.com/moonbitlang/Hackathon2026/pull/2) · [正式章程入口](https://bxup9uklfcb.feishu.cn/wiki/Dx4Bwd6D1i3GfHkajQCcF7SznEd)

## 生态与参考仓库

- Mooncakes 查询 `expression`、`spreadsheet` 和 `formula` 找到了相邻项目。MBEL 的公开接口面向 Jexl 风格表达式编译和上下文求值。MoonCell 面向 XLSX 公式诊断和候选修复影响预览，也有静态依赖传播。Tidemark 的交付重点是命名整数公式工作表的编译、快照复用和校验失败时的整批拒绝。依赖图及增量计算有相邻先例，独立贡献按这组明确的语义及可复现实例评估。[MBEL](https://github.com/dimon-83/mbel) · [MoonCell](https://github.com/icyaaaww/mooncell)
- 十月基线的整数优化属于与 `Freon793/moonopt` 相邻的方向，十一月工作表没有求解器依赖。对照项目只用于确定技术边界。[MoonOpt](https://mooncakes.io/docs/Freon793/moonopt@0.4.0)
- Scantling 的核心是 MQTT 双向报文、会话和确认状态，主要入口位于 `mqtt/`。Tidemark 的核心是编译期拓扑序及求值快照，代码沿用自己的 `worksheet/`、`cmd/`、`fieldbook/` 布局。以检查时的公开历史对照，Scantling 的 107 个提交和 Tidemark 十月基线的 29 个提交没有共同 SHA。[Scantling](https://github.com/Wchwch777/Scantling) · [Tidemark](https://github.com/WmmmQa/tidemark)

## 本地证据

三个阶段的实现范围及验证结果见[开发记录](november-development.md)。

- 基准与更新结果对比 49 组输入，覆盖多路依赖合流和重复读引用。另有 512 条语句的反向声明链、连续更新、相同值停止传播、重复名字、未知引用、环路径、算术边界和失败后重试。
- 从两个独立 `moon.mod` 组成的工作区导入公开库，验证输出 `Worksheet before/after: 12/16`。预算 CLI 初始执行 8 项，修改实际固定成本后执行 4 项。只改总表的表计案例报告第 2 行第 17 列 `check-failed`，进程退出 1。
- 工具链为 `moonc v0.10.20+65efd5b93`。原项目的派生注解与生成接口随工具链更新，现有优化、财务和 JSON 行为由既有测试复核。提交前验证命令见[使用说明](worksheet.md)。
- 源代码和合成示例由本仓库维护，采用 Apache-2.0。AI 辅助实现、测试和文档。十月申报存档含报名联系方式，十一月稿只写姓名和 GitHub ID。当前远端默认分支仍为十月基线，本地更新的 GitHub Actions 和 Mooncakes 发布待实际执行。
