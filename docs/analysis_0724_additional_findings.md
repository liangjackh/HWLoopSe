# `log.txt` 假反例的补充分析

## 1. 分析范围

本文是 `analysis_0724.txt` 的补充，分析对象为：

- `log.txt` 底部报告的 assertion violation；
- `designs/test-designs/test_vp_fsm.v` 的真实 SystemVerilog 时序语义；
- `engine/strategies.py` 中跨周期搜索、路径放弃及反例输出逻辑；
- `engine/symbolic_state.py` 中 SMT 查询统计逻辑。

原分析已经确认：日志底部的具体反例由错误 CFG 路径产生。本文不重复展开两条错误 CFG 边的构造过程，重点记录在此基础上还能得到的其他结论。

## 2. 总结

需要同时区分下面两个判断：

1. `log.txt` 底部报告的具体反例是假反例；
2. `assert (at_three == 0)` 这个属性本身确实不成立。

也就是说，工具当前给出的证据是错误的，但设计在另一个合法执行序列上存在真实 assertion violation。此外，日志还暴露了跨周期空转、SMT 重复统计、反例信息不足和值预测指标解释不充分等问题。

## 3. 发现一：属性本身存在真实反例

### 3.1 RTL 语义

设计的关键逻辑为：

```systemverilog
always @(posedge CLK) begin
  if (RST) begin
    state    <= 0;
    at_three <= 0;
  end else begin
    if (state == 3'd0)      state <= 3'd1;
    else if (state == 3'd1) state <= 3'd2;
    else if (state == 3'd2) state <= 3'd3;
    else                    state <= 3'd0;

    if (state == 3'd3) at_three <= 1;
    else               at_three <= 0;
  end
  assert (at_three == 0);
end
```

非阻塞赋值在 NBA 阶段生效，因此 assertion 读取的是本时钟沿开始时的 `at_three` 旧值。

### 3.2 合法失败序列

令 `RST` 在五个时钟沿持续为 0，初始值为 `state=0, at_three=0`：

| 时钟沿 | 边沿前 `state` | 边沿前 `at_three` | assertion | NBA 后 `state` | NBA 后 `at_three` |
|---:|---:|---:|---|---:|---:|
| 0 | 0 | 0 | 通过 | 1 | 0 |
| 1 | 1 | 0 | 通过 | 2 | 0 |
| 2 | 2 | 0 | 通过 | 3 | 0 |
| 3 | 3 | 0 | 通过 | 0 | 1 |
| 4 | 0 | 1 | **失败** | 1 | 0 |

周期 3 根据旧 `state=3` 排队执行 `at_three <= 1`。该赋值在 NBA 阶段生效，因此周期 4 执行 assertion 时读到 `at_three=1`，属性失败。

### 3.3 结论

原分析中“这是一个假反例”应精确表述为：

> `log.txt` 底部所报告的 Cycle 0/Cycle 2 反例是假反例，但被检查的属性并非安全属性；`RST` 连续为 0 时，周期 4 存在一个真实反例。

因此，修复 CFG 后不能期待本测试最终得到“属性成立”。正确的回归目标应是：工具不再报告当前错误路径，而是报告连续五周期 `RST=0` 的合法失败路径。

如果这个 testcase 原本用于演示“安全设计上的值预测”，则需要重新设计 assertion；不能继续使用永久要求 `at_three==0` 的属性。

## 4. 发现二：全路径跳过后仍推进周期

### 4.1 日志证据

日志中出现：

```text
[AllSkipped] cycle 1: preferred-path item, all CFGs abandoned — continuing to next cycle
```

随后路径条件从 `RST_c0` 直接出现 `RST_c2`，最终 counterexample trace 也只有 Cycle 0 和 Cycle 2，没有 Cycle 1。

### 4.2 对应实现

`engine/strategies.py` 的 `_execute_cycle()` 在本周期所有 CFG 都被跳过时，对 forked item 进行剪枝，但对 preferred-path item 继续执行周期尾逻辑：

```python
if not any_cfg_executed:
    is_forked_item = any(rc.get('forked', False) for rc in remaining_cfgs)
    if is_forked_item:
        return None, item.milestones_completed
    print("... continuing to next cycle")

return self._execute_cycle_tail(...)
```

在此之前，被放弃 CFG 的 store、pending NBA 和 path condition 已回滚。因而该逻辑会让周期编号前进，但没有执行对应的 sequential transition。

### 4.3 风险

这不是纯粹的显示问题，而是一种没有明确 RTL 语义的“空转周期”：

- 周期编号增长，但寄存器没有执行一次有效时钟转移；
- 当前周期输入可能没有进入完整路径约束；
- 跨周期依赖和值预测的 cycle stamp 发生错位；
- `max_cycles` 可能包含未执行有效硬件行为的周期；
- 既可能制造假反例，也可能漏掉真实反例。

### 4.4 修复建议

preferred path 不可行时，不应简单把原状态推进到下一周期。至少应满足以下一种处理语义：

1. 继续尝试同一 CFG 的其他可行 sibling；
2. 如果能证明整个 CFG 在当前 path condition 下均不可行，则剪掉 work item；
3. 如果确实需要支持 stutter，必须显式定义其硬件语义，并保证输入、时钟和状态约束完整，而不能由路径执行失败隐式产生。

## 5. 发现三：SMT 查询和时间存在嵌套重复统计

### 5.1 日志表现

日志中大量出现以下形式：

```text
[Z3-QUERY #0] ...
[Z3-QUERY #0] ...
[Z3-RESULT #0] sat
[Z3-RESULT #1] sat
```

这表明同一组 assertions 被打印两次，并消耗两个查询编号。

### 5.2 根因

`SymbolicState.pc` 是 `_LazyPC` 包装器，其 `check()` 已经负责调用统计器：

```python
def check(self):
    return smt_stats.timed_check(self._build_solver())
```

但部分通用代码又调用：

```python
smt_stats.timed_check(s)
```

当这里的 `s` 实际是 `_LazyPC` 时，调用关系变成：

```text
timed_check(_LazyPC)
  -> _LazyPC.check()
       -> timed_check(real Z3 Solver)
```

于是一次真实的底层 `Solver.check()` 被外层和内层各统计一次。

### 5.3 影响

- 最终的 `SMT queries 305` 不是可靠的底层 Z3 求解次数；
- 同一查询日志重复；
- 外层计时覆盖整个内层调用，内层又单独累计一次，因此 SMT solver time 也可能重复累计；
- 使用这些数字比较优化前后性能可能得到错误结论。

### 5.4 修复建议

统一 SMT 检查入口，保证统计只包围真实的 Z3 `Solver.check()` 一次。可选择：

- 所有调用方直接使用 `state.pc.check()`；或
- 让 `timed_check()` 识别 `_LazyPC` 并提取真实 solver；或
- 为 path-condition wrapper 和原生 solver 提供统一、不可嵌套的检查接口。

同时增加单元测试，断言一次逻辑 SAT 检查只增加一次 `query_count`。

## 6. 发现四：当前反例输出不足以复现 violation

日志最终只给出：

```text
Counterexample trace (cycle-by-cycle):
  Cycle 0:
    RST = 0x0
  Cycle 2:
    RST = 0x1
```

但没有给出：

- `state` 的逐周期值；
- `at_three` 的逐周期值；
- assertion 读取的是 pre-NBA 还是 post-NBA 值；
- 每周期选中的 CFG path 和基本块序列；
- 每周期排队及应用的 NBA；
- Cycle 1 为什么缺失。

此次假反例正是由非法 CFG path 引起的，仅打印 primary input 无法揭示或复现这类问题。

建议 counterexample 至少记录：

```text
cycle
primary inputs
pre-state
CFG/path/block decisions
pending NBA
post-state
assertion expression and evaluated value
```

对于内部寄存器，即使它们没有作为独立自由变量出现在 Z3 model 中，也应通过 `model.eval(state_expression, model_completion=True)` 计算并输出，而不应只打印 model declarations。

## 7. 发现五：值预测统计不能证明本次路径选择得到加速

摘要同时给出：

```text
forced (prunable) ratio: 80.0%
path selections guided: 0
```

`80%` 表示预测器把许多分支分类为 forced，但 `path selections guided: 0` 表示没有一次实际路径选择因预测结果而改变。

因此，本次运行不能作为“值预测成功引导搜索并更快发现反例”的证据。最终 violation 更可能来自 CFG alternatives 的常规排队探索，而且还是一条非法 CFG 路径。

建议性能报告至少同时展示：

- 被预测的分支数；
- 实际改变 preferred path 的次数；
- 因预测而避免创建或执行的路径数；
- 预测正确率；
- 修复 CFG 后与禁用值预测时的 wall time、真实 SMT checks 和 explored paths 对比。

## 8. 修复优先级

建议按以下顺序处理：

1. **修复 CFG 构建**：去除 then/else 串联边、条件节点之间绕过叶子赋值块的捷径边，并为每个条件建立正确 join；
2. **修复 assertion 后继关系**：保证 `at_three<=1` 和 `at_three<=0` 两个分支最终都能到达分支后的 assertion；
3. **修复 AllSkipped 周期推进**：禁止因 preferred path 不可行而产生隐式空转周期；
4. **修复 SMT 统计嵌套**：确保一个真实 solver check 只统计一次；
5. **增强反例输出**：加入内部状态、NBA 和 CFG path 信息；
6. **重新评估值预测效果**：在语义正确的 CFG 和可靠统计基础上重新采集实验数据。

## 9. 建议的最小回归测试

### 9.1 CFG 结构测试

对 `test_vp_fsm.v` 构图后断言：

- RST then 分支出口不能进入 RST else 分支；
- state 的 if/else-if 链每个可行叶子都连接到第二个 `if (state==3)`；
- 不能存在从 state 条件节点直接绕过全部赋值叶子的边；
- `at_three<=1` 和 `at_three<=0` 两个分支都能到达 assertion。

### 9.2 真反例测试

固定五周期：

```text
RST_c0 = 0
RST_c1 = 0
RST_c2 = 0
RST_c3 = 0
RST_c4 = 0
```

预期仅在周期 4 报告 violation，并输出：

```text
pre-state: state=0, at_three=1
assert(at_three == 0): false
```

### 9.3 复位互斥测试

任一周期 `RST=1` 时，执行路径不得包含 RST else 分支内的 state 条件或 `if (state==3)` 条件。

### 9.4 周期连续性测试

若 trace 覆盖 Cycle 0 到 Cycle N，则必须：

- 每个周期都有明确的输入与状态转移记录；
- 不允许因 `AllSkipped` 无声缺失中间周期；
- cycle-stamped symbols 不应从 `_c0` 无原因跳到 `_c2`。

### 9.5 SMT 统计测试

执行一次 `state.pc.check()`，预期：

```text
query_count increment == 1
Z3-QUERY lines == 1
Z3-RESULT lines == 1
```

## 10. 最终判断

此次日志不能被解释为“工具找到了设计的真实反例”，也不能被解释为“设计属性成立，只是工具误报”。准确判断是：

> 当前报告的具体 witness 是由 CFG 和跨周期搜索缺陷共同污染的假证据；与此同时，RTL 中的 assertion 在连续无复位运行五个时钟沿时确实会失败。修复后的工具应拒绝当前 Cycle 0/Cycle 2 witness，并找到周期 4 的合法真实反例。
