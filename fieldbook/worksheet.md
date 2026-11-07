# Tidemark 整数公式工作表

`WmmmQa/tidemark/worksheet` 可嵌入需要重复计算同一份公式的程序。业务方将输入、公式和守恒条件写在文本里，调用方传入整数。工作表的计算和校验都在 MoonBit 内执行。

## 复现

从项目根目录运行。JS 后端需要 Node.js。配置好 C 工具链后，可将 `--target js` 换成 `--target native`。

~~~powershell
$model = Get-Content -Raw examples/budget-reconcile.worksheet
moon run --target js cmd/reconcile -- $model units=85 actual_price=7500 actual_cost=4900 actual_fixed=120000 budget_units=100 budget_price=8000 budget_cost=4800 budget_fixed=100000 --edit actual_fixed=110000

$meter = Get-Content -Raw examples/meter-balance.worksheet
moon run --target js cmd/reconcile -- $meter opening=100 closing=180 branch_a=35 branch_b=45 --edit closing=190 branch_b=55
moon run --target js cmd/reconcile -- $meter opening=100 closing=180 branch_a=35 branch_b=45 --edit closing=190
~~~

- 预算例使用合成数据，金额以分表示。基准营业利润 101,000，预算利润 220,000，四项差异之和为 −119,000。将实际固定成本从 120,000 改为 110,000 后，差额变为 −109,000。实际利润、固定成本差异、差异汇总和校验共重算 4 项，首次执行 8 项。
- 表计例的合成读数以整数 Wh 表示。同步更新总表和支路通过校验，分发电量从 80 变为 90。只改总表时，第 2 行第 17 列报告 `check-failed`，明细为 `90 != 80`，进程退出码为 1。库调用者仍可从旧快照发起另一批更新。
- CLI 将文本作为第一个参数传入，随后是 `name=integer`，可选 `--edit` 分隔一批修改。文本大小还受终端和操作系统参数长度限制。结果的 `values` 用十进制字符串保存所有 Int64 值，`evaluated` 是执行过的公式及校验数。工作表错误输出 JSON 并退出 1，参数错误退出 2。

## 语言及运行约定

| 语句 | 含义 |
| --- | --- |
| `input units` | 声明由调用方绑定的值 |
| `let sales = units * price` | 定义命名公式，可引用后续声明 |
| `check sales == reported_sales` | 比较两个整数表达式，失败时拒绝本次计算 |
| `# comment` | 注释，也可写在语句之后 |

一行一条语句，支持空行、LF 和 CRLF。名字区分大小写，采用 `[A-Za-z_][A-Za-z0-9_]*`。表达式支持十进制整数、括号、一元负号、`+ - * /`，乘除优先于加减，同级二元运算左结合。全部值和中间结果须适配有符号 Int64，除法须整除。源文本上限 65,536 个 UTF-16 代码单元，每行最多 512 个字符，最多 512 条语句，括号和递归一元表达式的嵌套上限为 32。诊断行列从 1 开始，列按 Unicode 字符计数。未声明的外部绑定用 `(0, 0)`。

编译先登记符号，再把引用链接成槽位，记录正向和反向边，用拓扑排序生成可重用的执行计划。对剩余节点沿未解析的前置依赖回溯，报告真实环路径。表达式编译成后缀指令，由值栈求值。每次更新先复制旧值，再传播变更。一条公式即使执行过，只要结果相同，就不会继续标记下游。更新仍需线性扫描拓扑序并复制槽位，执行成本另取决于被标记行的指令数。错误时丢弃本次工作副本，调用方保有原快照。

工作表适用于固定公式、重复换输入的场景。它的语法不含浮点、循环、函数、外部文件或网络访问。业务校验由作者写明，单位由调用方统一。

## 嵌入与测试

`moon.pkg` 导入 `WmmmQa/tidemark/worksheet`。调用 `compile(source)` 获得 `Program`，用 `evaluate(bindings)` 生成快照。用 `Snapshot::update(edits)` 派生下一份快照，通过 `value(name)` 或 `entries()` 读结果。所有失败通过 `Fault(Position, Code, detail)` 返回，`Code::name()` 提供稳定标签。编译和两种求值路径的可执行 API 示例见 [worksheet/usage.mbt.md](../worksheet/usage.mbt.md)。

~~~sh
moon fmt --check
moon check --target js --deny-warn
moon test --target js --deny-warn
moon check --target native --deny-warn
moon test --target native --deny-warn
~~~
