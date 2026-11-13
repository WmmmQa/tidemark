# 工作表规则升级回放

十一月复审指出，通用增量库已覆盖原方案的多项核心职责。以 [incr 0.15.1 的公开 API](https://mooncakes.io/docs/dowdiness/incr@0.15.1) 为对照，依赖追踪、跳过重算、批量更新回滚和成功门控快照都有现成接口。incr 还展示了电子表格用法。这些能力属于对照基线。

本次新增的交付是规则变更审查。给定两份工作表和一批有名称的历史输入，调用方可以在发布前找出哪些案例从通过变为失败、哪些从失败变为通过，以及两版都通过时哪些命名公式的输出发生新增、删除或数值变化。旧版和候选版都复用既有解释器，分别按输入求值。每组案例独立，失败保留所属版本的错误位置与原因，后续案例继续执行。

## 复现库存规则变更

从仓库根目录在 PowerShell 运行。

~~~powershell
$old = Get-Content -Raw examples/revision-baseline.worksheet
$new = Get-Content -Raw examples/inventory-close-v2.worksheet
moon run --target js cmd/reconcile -- --compare $old $new 'schema:opening=120,received=30,shipped=45,counted=105,damaged=0' 'regression:opening=120,received=30,shipped=45,counted=105,damaged=4' 'recovery:opening=120,received=30,shipped=45,counted=101,damaged=4'
~~~

合成案例中，`schema` 两版均通过，但旧公式 `movement` 被删除，新公式 `net_movement` 被加入。 `regression` 仅候选版拒绝，在候选版第 9 行第 19 列报告 `4 != 0`。 `recovery` 仅旧版拒绝，在旧版第 10 行第 19 列报告 `-4 != 0`。

## API 与边界

另两类合成规则变更可直接通过同一 CLI 验证。表计从严格守恒改为扣除已知线损，历史严格一致记录仍通过，计入 2 Wh 线损的记录从拒绝变为通过。结算费率从每件 10 分改为 12 分，两版均接受历史输入，但 5 件的输出从 50 分变为 60 分，发布检查退出 3。

~~~powershell
$oldMeter = "input total`ninput branches`ninput loss`ncheck total == branches"
$newMeter = "input total`ninput branches`ninput loss`ncheck total - loss == branches"
moon run --target js cmd/reconcile -- --gate $oldMeter $newMeter 'balanced:total=80,branches=80,loss=0' 'line-loss:total=82,branches=80,loss=2'
$oldFee = "input units`nlet fee = units * 10"
$newFee = "input units`nlet fee = units * 12"
moon run --target js cmd/reconcile -- --gate $oldFee $newFee 'historical:units=5'
~~~

`worksheet.compare_revisions` 接受两个编译后的 Program 和一组 ReplayCase。结果按输入案例顺序排列。比较按名字对齐全部命名公式，输入字段和匿名校验行不作为输出字段。报告中的 `null` 表示该侧公式缺失，整数以字符串保存。若某侧拒绝，结果保留诊断，不提供该侧的部分公式值。每个案例只保留每版首个错误。两版都拒绝也会分别报告。

CLI 成功生成报告时退出码为 0，部署决策由报告消费者按状态制定。无法编译的工作表会给出所属版本并退出 1，CLI 参数错误退出 2。两版使用同一份绑定，输入字段契约改变也会体现在对应版本的拒绝诊断中。重放结论限于所给案例，不能证明两版对任意输入等价，也不会自动迁移数据。

将命令中的 `--compare` 换成 `--gate`，即可在保留完整报告的同时检查发布条件。候选版拒绝原本通过的案例，或者两版均通过但既有命名公式被删除或变值，均退出 3。仅新增公式、旧版拒绝而新版通过、两版都拒绝时均保留报告，且这些结果本身不会触发退出 3。这是基于旧版成功案例的兼容性检查，不能替代候选版的业务验收。

库的回归测试覆盖输出按名称对齐、声明顺序变化、新增、删除、数值变化、等价，以及双向和双侧拒绝。现阶段差异依据是上述工作表发布前审查的端到端交付，未做对整个 MoonBit 生态的唯一性声明。

本地复核记录：JS、Wasm、Linux 原生各通过 106 项仓库测试。库存案例已在 JS 和 Linux 原生命令行运行，原有 JS 财务案例回归通过。

复审材料可围绕「规则发布前，如何识别历史输入上的兼容性变化」组织。本人可先复现三个案例，再说明为何不能用一个总通过数代替逐案例差异，以及为何旧版和候选版都失败时仍需保留两个诊断。以实际运行和理解为依据自行撰写正式申报书。
