# HackAtDAC18 超时属性分析报告

**日期**：2026-05-09  
**涉及属性**：HACKDAC_p5、HACKDAC_p11、HACKDAC_p13、HACKDAC_p14  
**超时阈值**：300s

---

## 一、背景：Suppression 机制

### 设计初衷

Symbolic execution 在 cycle 0 时，所有信号都是自由的 Z3 变量，没有任何约束。这意味着几乎任何断言都可以被"违反"——Z3 只需随便选一个满足违反条件的值即可。这种违反是**虚假的（spurious）**，不代表设计真正存在的 bug，只是因为输入还没有被 reset 序列约束。

Suppression 机制的目标是：**只在路径已经经历了足够的"真实"约束之后，才报告 violation**。

### 工作原理

核心逻辑在 `engine/strategies.py` 的 `_execute_cycle` 中：

```python
if result == "VIOLATION":
    if item.milestones_completed >= total_milestones - 1:
        return "VIOLATION", current_progress   # 报告
    else:
        if _is_unconditional and cycle > 0:
            return "VIOLATION", current_progress   # 无条件违反，立即报告
        # 否则压制
        self._deferred_violation = (violated_assertions, clone_of_state)
        manager.assertion_violation = False    # 清除标志，继续探索
```

**报告条件**：`milestones_completed >= total_milestones - 1`，即已完成的 milestone 数量达到"倒数第二个"（penultimate）。

### 三种处理路径

```
violation 触发
      │
      ├─ milestones >= total-1 ──────────────────→ 立即报告
      │
      ├─ unconditional（路径条件无自由变量）
      │   且 cycle > 0 ──────────────────────────→ 立即报告
      │
      └─ 其他情况 ──────────────────────────────→ [Suppressed]
              │
              ├─ 保存到 _deferred_violation
              ├─ 清除 manager.assertion_violation
              └─ 继续探索，等待 milestone 推进
                      │
                      ├─ sliding window 推进到 >= total-1 → 报告 deferred violation
                      └─ 达到 ALL_MILESTONES ──────────→ 报告 deferred violation
```

### 机制的本质假设与失效条件

Suppression 机制假设：**violation 出现得越晚（milestone 越高），越可信**。

该假设在两种情况下失效：

| 失效类型 | 描述 | 涉及属性 |
|---------|------|---------|
| Milestone 设计冗余 | 最后几个 milestone 条件与 violation 条件重叠或相同，sliding window 无法推进，deferred violation 永远等不到报告时机 | p11、p13 |
| Milestone 跨度过大 | violation 在早期 milestone 就已真实可达，但 suppression 要求继续推进到更高 milestone，而更高 milestone 的条件在有限 cycle 内不可达 | p5、p14 |

---

## 二、逐属性分析

### 2.1 HACKDAC_p5

**属性描述**：GPIO lock 寄存器在 HRESETn 复位时不清零。

**Target 表达式**：
```
top_wrapper.apb_gpio.HRESETn == 0 && top_wrapper.apb_gpio.r_gpio_lock != 32'h00000000
```

**Milestone 配置**：

| Step | 条件 | expected_cycles |
|------|------|----------------|
| 0 | `rstn_top == 1 && HRESETn == 1` | 1 |
| 1 | `r_gpio_lock != 0` | 3 |
| 2 | `HRESETn == 0 && r_gpio_lock != 0` | 2 |

**运行数据**：
- 探索路径数：29,341
- 最终 queue 大小：~307（从峰值 6,562 下降）
- 卡住位置：milestones=1/3
- Suppressed violations：29,341 次（每条路径都触发）

**根因分析**：

这是四个属性中最严重的案例。Milestone 2 的条件与 target_expr 完全相同，即 **milestone 2 本身就是 violation**。Suppression 机制要求 `milestones >= 2`（total-1=2）才报告，但：

1. Violation 在 milestones=1/3 时就已经被触发（`r_gpio_lock != 0` 且 `HRESETn` 可以自由取 0）
2. 报告条件要求先达到 Milestone 1（APB 写入使 lock 非零），再达到 Milestone 2
3. 但 Milestone 2 = violation，引擎无法"先达到 milestone 2 再报告 violation"
4. Milestone 1 的 APB 写入协议需要多个 cycle，`expected_cycles=3` 不足以在有限深度内完成
5. 结果：29,341 条路径全部在 milestones=1/3 被压制，引擎耗尽时间

**Milestone 设计问题**：Milestone 2 不应该与 target_expr 相同。正确的设计应该让 milestone 序列引导搜索到达 violation，而不是把 violation 本身作为 milestone。

**修复建议**：
- 删除 Milestone 2（它与 target 重复），将 Milestone 1 的 `expected_cycles` 改为 1
- 或者：将 Milestone 1 拆分为更细的 APB 协议步骤（PSEL→PENABLE→PWRITE）

---

### 2.2 HACKDAC_p11

**属性描述**：调试状态寄存器在核心非 halt 状态时被读取。

**Target 表达式**：
```
top_wrapper.riscv_core.debug_unit_i.dbg_halt != 1 &&
top_wrapper.riscv_core.debug_unit_i.rdata_sel_n == 3'b100
```

**Milestone 配置**：

| Step | 条件 | expected_cycles |
|------|------|----------------|
| 0 | `rstn_top == 0` | 1 |
| 1 | `rstn_top == 1` | 1 |
| 2 | `dbg_halt == 0` | 2 |
| 3 | `dbg_halt != 1 && rdata_sel_n == 3'b100` | 1 |

**运行数据**：
- 探索路径数：229
- 最终 queue 大小：5,735
- 卡住位置：milestones=3/4
- Suppressed violations：0（从未找到 violation）

**根因分析**：

Milestone 1（`rstn_top==1`）被 sliding window 识别为 hallucinated 并跳过，直接推进到 milestones=3/4。此时引擎认为已经接近终点，但实际上 violation 的第二个条件 `rdata_sel_n == 3'b100` 从未被满足：

1. Milestone 2（`dbg_halt==0`）和 Milestone 3（`dbg_halt!=1 && rdata_sel_n==3'b100`）的第一半条件相同
2. Sliding window 在达到 Milestone 2 时直接跳到 3/4，但 `rdata_sel_n` 这个信号从未被引导到 `3'b100`
3. 引擎以为已经在 3/4，但 violation 条件的关键部分（`rdata_sel_n`）从未被约束
4. 229 条路径全部在 milestones=3/4 继续探索，queue 膨胀到 5,735，无法找到 violation

**Milestone 设计问题**：Milestone 2 和 Milestone 3 的条件高度重叠，缺少对 `rdata_sel_n` 的引导步骤。

**修复建议**：在 Milestone 2 和 3 之间插入一个专门引导 `rdata_sel_n` 的步骤：
```json
{ "step": 2, "condition": "dbg_halt == 0", "expected_cycles": 2 },
{ "step": 3, "condition": "rdata_sel_n == 3'b100", "expected_cycles": 2 },
{ "step": 4, "condition": "dbg_halt != 1 && rdata_sel_n == 3'b100", "expected_cycles": 1 }
```

---

### 2.3 HACKDAC_p13

**属性描述**：CPU 控制器 FSM 在 DECODE 状态下自循环（不跳出）。

**Target 表达式**：
```
top_wrapper.riscv_core.id_stage_i.controller_i.ctrl_fsm_ns == 5'b00101
```

**Milestone 配置**：

| Step | 条件 | expected_cycles |
|------|------|----------------|
| 0 | `rstn_top == 0` | 1 |
| 1 | `rstn_top == 1 && ctrl_fsm_ns == 5'b00000` (RESET) | 1 |
| 2 | `ctrl_fsm_ns == 5'b00001` (BOOT_SET) | 2 |
| 3 | `ctrl_fsm_ns == 5'b00101` (DECODE) | 3 |
| 4 | `ctrl_fsm_ns == 5'b00101` (DECODE 自循环，violation) | 1 |

**运行数据**：
- 探索路径数：234
- 最终 queue 大小：5,664
- 卡住位置：milestones=2/5
- Suppressed violations：多次（milestones=2/5 时触发）

**根因分析**：

Violation 在 milestones=2/5 时就已经被触发，说明 `ctrl_fsm_ns==DECODE` 是可达的。但 Suppression 要求 `milestones >= 4`，而：

1. Milestone 3 和 Milestone 4 的条件完全相同（都是 `ctrl_fsm_ns == 5'b00101`）
2. 引擎无法区分"第一次到达 DECODE"和"DECODE 自循环"——它们是同一个条件
3. Sliding window 无法从 Milestone 2 推进到 3，因为 Milestone 3 的条件（DECODE）在 milestones=2 时已经满足，但 suppression 阈值是 4
4. FSM 从 BOOT_SET 到 DECODE 需要经过 BOOT_WAIT→FIRST_FETCH 等中间状态，milestone 跨度（`expected_cycles=3`）不足以覆盖完整路径

**Milestone 设计问题**：
- Milestone 3 和 4 条件相同，无法区分"到达"和"停留"
- BOOT_SET 到 DECODE 之间缺少中间状态引导

**修复建议**：
1. 补充 FSM 中间状态作为 milestone：
```json
{ "step": 2, "condition": "ctrl_fsm_ns == 5'b00001", "expected_cycles": 2 },  // BOOT_SET
{ "step": 3, "condition": "ctrl_fsm_ns == 5'b00010", "expected_cycles": 2 },  // BOOT_WAIT
{ "step": 4, "condition": "ctrl_fsm_ns == 5'b00101", "expected_cycles": 3 },  // DECODE
{ "step": 5, "condition": "ctrl_fsm_ns == 5'b00101", "expected_cycles": 1 }   // 自循环
```
2. 或者：将 Milestone 4（violation）的 suppression 阈值降低，允许在 milestones=2 时就报告

---

### 2.4 HACKDAC_p14

**属性描述**：ALU 在向量模式（VEC_MODE16/VEC_MODE8）下，进位位 `adder_in_a[18]` 未被清零。

**Target 表达式**：
```
(top_wrapper.riscv_core.ex_stage_i.alu_i.vector_mode_i == 2'b10 ||
 top_wrapper.riscv_core.ex_stage_i.alu_i.vector_mode_i == 2'b11) &&
top_wrapper.riscv_core.ex_stage_i.alu_i.adder_in_a[18] == 1'b1
```

**Milestone 配置**：

| Step | 条件 | expected_cycles |
|------|------|----------------|
| 0 | `rstn_top == 0` | 1 |
| 1 | `rstn_top == 1` | 1 |
| 2 | `vector_mode_i == 2'b10 \|\| 2'b11` | 3 |
| 3 | `vector_mode_i == 2'b10/11 && adder_in_a[18] == 1` | 1 |

**运行数据**：
- 探索路径数：222
- 最终 queue 大小：5,769
- 卡住位置：milestones=2/4
- Suppressed violations：0（从未找到 violation）

**根因分析**：

这是四个属性中唯一一个 violation 从未被触发的案例。问题在于 `vector_mode_i` 的可达性：

1. `vector_mode_i` 是 ALU 的输入，但它不是 primary input——它由 decoder 根据指令编码计算，需要完整的取指→译码→执行流水线
2. 从 reset 释放到 ALU 收到向量模式指令，需要至少 4-6 个 cycle（取指 latency + 流水线级数）
3. Milestone 2 的 `expected_cycles=3` 不足以让流水线完成一次完整的向量指令执行
4. 引擎在有限深度内无法将 `vector_mode_i` 约束到 `2'b10` 或 `2'b11`，导致 Milestone 2 永远无法达到
5. 222 条路径全部卡在 milestones=2/4，queue 膨胀到 5,769

**Milestone 设计问题**：`expected_cycles` 严重低估了流水线深度，且缺少对流水线前级（取指、译码）的引导条件。

**修复建议**：
1. 将 Milestone 2 的 `expected_cycles` 增加到 6-8
2. 增加流水线前级引导步骤，例如：
```json
{ "step": 2, "condition": "instr_valid_i == 1", "expected_cycles": 3 },
{ "step": 3, "condition": "vector_mode_i == 2'b10 || vector_mode_i == 2'b11", "expected_cycles": 3 },
{ "step": 4, "condition": "...", "expected_cycles": 1 }
```
3. 确认 `vector_mode_i` 是否在 COI 分析中被识别为可达信号

---

## 三、问题汇总

| 属性 | 卡住位置 | 根因类型 | Violation 是否找到 | 修复难度 |
|------|---------|---------|-----------------|---------|
| p5 | milestones=1/3 | Milestone 2 = target，suppression 阈值设置错误 | ✅ 已找到，被压制 | 低 |
| p11 | milestones=3/4 | Milestone 条件重叠，rdata_sel_n 缺少引导 | ❌ 未找到 | 中 |
| p13 | milestones=2/5 | Milestone 3/4 条件相同，FSM 中间状态缺失 | ✅ 已找到，被压制 | 低 |
| p14 | milestones=2/4 | 流水线信号不可直接驱动，expected_cycles 不足 | ❌ 未找到 | 高 |

### 两类问题

**类型 A：Violation 已找到，但被 Suppression 阻止报告**（p5、p13）

这类问题修复成本低。Violation 已经存在于搜索空间中，只需调整 milestone 文件，让 suppression 阈值能够被满足，或者删除冗余的 milestone 条件。

**类型 B：Violation 从未被找到**（p11、p14）

这类问题需要更深入的 milestone 设计。需要分析目标信号的数据流路径，在 milestone 中补充引导步骤，或增加 `expected_cycles`。

---

## 四、通用改进建议

1. **避免 Milestone 条件与 target_expr 相同**：最后一个 milestone 应该是 violation 的前置条件，而不是 violation 本身。

2. **避免相邻 Milestone 条件重叠**：如果 Milestone N 和 N+1 的条件有大量重叠，sliding window 可能无法正确区分，导致 suppression 阈值永远无法满足。

3. **根据信号的数据流深度设置 expected_cycles**：对于流水线内部信号（如 `vector_mode_i`），需要考虑从 primary input 到该信号的完整传播路径，而不是简单地设置一个小数值。

4. **对"类型 A"问题考虑引入更宽松的 suppression 策略**：当 violation 在 milestones=N/M 时被触发，且 N >= M-2（已经接近终点），可以考虑直接报告，而不是继续等待。
