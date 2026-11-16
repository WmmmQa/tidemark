# 工作表静态单位检查

最新驳回意见针对的是已有解释器逐例运行、按名比较和固定规则拦截。此次新增检查器在执行任何整数运算前沿编译后的指令推导单位。它能检查尚没有历史案例的规则，也能发现恰好用同一个数字填入两种单位而导致的假通过。

| 对照 | 已有公开能力 | 本轮提交范围 |
| --- | --- | --- |
| [incr](https://mooncakes.io/docs/dowdiness/incr) | 依赖追踪、增量求值与批量更新 | 对文本工作表的全部公式和校验做静态单位检查 |
| [Kiln](https://mooncakes.io/docs/DWS-ai-nb/kiln) | 有限域新旧规则比较及反例 | 使用输入单位声明推导每条公式的单位，无需枚举数值 |
| [LunarUnits](https://mooncakes.io/docs/FrozenLemonTee/LunarUnits) | 物理维度、量与单位运算 | 将单位检查接入工作表编译结果，追踪到所在操作符行列，并允许自定义货币和业务计数符号 |

调用 `Program::check_units`，为每个输入声明因子及指数。无单位的输入用空数组。乘和除分别累加和扣减指数，指数为零的因子消去。加减和等式校验要求两边单位完全一致。检查按依赖顺序进行，允许前向引用。首个不匹配返回 `Fault`，带操作符行列号及两边的单位。源代码和测试均在 `worksheet/`。

## 从仓库根目录复现

安装 MoonBit 和 Node.js。以下是 PowerShell 命令，三个工作表都是合成案例。
在 Bash 中可将 `$model` 替换为 `"$(cat examples/对应文件.worksheet)"`。
`--check-units` 只接收单位声明，格式为 `输入名=符号^指数`。
复合单位用逗号连接，`输入名=1` 表示无单位。

### 计费 · 推导公式结果

商品数量以件计，单价是分每件，发票金额以分计。推导得到 `charge = fen^1`，退出码为 0。

```powershell
$model = Get-Content -Raw examples/billing-units.worksheet
moon run --target js cmd/reconcile -- --check-units $model 'quantity=item^1' 'price=fen^1,item^-1' 'invoice=fen^1'
```

### 库存 · 找出数值恰好相等时的漏判

盘点件数误和账面金额比较。两者填入 5 时，数值校验成功。输入单位声明后，静态检查在第三行第 15 列的等号处返回 `item^1 vs fen^1`，退出码为 1。

```powershell
$model = Get-Content -Raw examples/inventory-unit-mismatch.worksheet
moon run --target js cmd/reconcile -- $model counted=5 book_value=5
moon run --target js cmd/reconcile -- --check-units $model 'counted=item^1' 'book_value=fen^1'
```

### 表计 · 定位两个支路的单位冲突

总表期初、期末及两条支路统一用 Wh 时，推导得到 `delivered = Wh^1`，退出码为 0。
把第二条支路标成 kWh 后，第二行第 29 列的加号报 `Wh^1 vs kWh^1`，退出码为 1。

```powershell
$model = Get-Content -Raw examples/meter-balance.worksheet
moon run --target js cmd/reconcile -- --check-units $model 'opening=Wh^1' 'closing=Wh^1' 'branch_a=Wh^1' 'branch_b=Wh^1'
moon run --target js cmd/reconcile -- --check-units $model 'opening=Wh^1' 'closing=Wh^1' 'branch_a=Wh^1' 'branch_b=kWh^1'
```

单位符号由调用方约定，`Wh` 与 `kWh` 不会自动换算。所有整数常量都是无单位值，带单位的阈值需要声明为输入。因子指数限制在 −1024 到 1024。命令成功时输出公式名及规范化后的单位因子，首次静态错误输出诊断并退出。声明参数格式错误的退出码为 2。规则的单位正确仍需用回放验证业务结果。

工作表包测试可通过 `moon test worksheet --target js --deny-warn` 运行。
