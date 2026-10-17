# HWLoopSe (LoopSE)

LoopSE 是一个针对 SystemVerilog 设计的符号执行引擎。它用 PySlang 解析 AST、构建
控制流图（CFG），再用 Z3 做约束求解，逐周期探索设计的执行路径，寻找 assertion
违例并生成反例。

## 依赖

- Python 3.9+
- [`pyslang`](https://pypi.org/project/pyslang/)（SystemVerilog 前端解析）
- [`z3-solver`](https://pypi.org/project/z3-solver/)
- `networkx`（CFG 图结构）
- 可选：`redis`（`--use_cache` 需要本机 `redis-server` 跑在 `localhost:6379`）
- 可选：`openai` / `anthropic`（`--auto-plan` 走 LLM 生成里程碑时需要）

```bash
pip install pyslang z3-solver networkx redis openai anthropic
```

## 基本用法

```bash
python3 -m main <num_cycles> <verilog_file>.v --sv [options]
```

- `<num_cycles>`：要探索的时钟周期数（正整数）
- `<verilog_file>.v`：待分析的设计文件（也可以传多个文件，会自动生成 `.F` filelist）
- `--sv` 是必需的——当前只支持 SystemVerilog 前端

最简单的例子（1 个周期，几十毫秒跑完）：

```bash
python3 -m main 1 designs/test-designs/test_vp_fsm.v --sv --explore_time 20
```

跑完会打印每条探索路径的 `[Run]`/`[Exec]`/`[Fork]` 等日志，最终报告：

- 找到违例：打印 `Assertion violation detected!` 和逐周期的反例赋值（counterexample trace）
- 没找到：打印 `Search exhausted (UNSAT)` / `... exploration complete — no assertion violation found (UNSAT)`

## 探索策略：怎么选

引擎支持三种探索策略，通过 `--strategy` 选择，且可以叠加 `--value_predict`：

| 场景 | 命令 | 用哪个策略类 |
|---|---|---|
| 穷举所有路径组合，设计小、周期少 | `--strategy blind`（默认） | `BlindSearchStrategy` |
| 有具体验证目标（milestone 文件或 `--auto-plan`），想让搜索朝目标前进 | `--strategy directed --milestone-file xxx.json` 或 `--auto-plan` | `MilestoneDirectedStrategy` |
| 没有里程碑，但想让搜索利用寄存器值预测更快找到 assertion 违例 | `--value_predict`（不加 `--milestone-file`/`--auto-plan`） | `ValuePredictDirectedStrategy` |

### 1. Blind search（默认）

```bash
python3 -m main 1 designs/test-designs/test_vp_fsm.v --sv --explore_time 60
```

用生成器做所有周期 × 所有 CFG 路径的笛卡尔积穷举，不做任何裁剪，结论最可靠，
但路径数随周期数指数增长，只适合小设计或少周期数。例如上面这个只有一个 14
路径 CFG 的小 FSM，1 个周期几十毫秒跑完，但把周期数提到 4 就是 14⁴ 量级的组合，
实测要跑 40+ 秒、产生近百万行日志——周期数大时应该换成下面的 directed 或
value-predict 策略。

### 2. Directed search（里程碑导向）

需要先有一组"里程碑"（milestone）描述设计从复位到触发某个 assertion 需要经过
哪些中间状态，搜索会用优先队列优先探索朝里程碑推进的路径，同时对提前触发的
assertion 违例做抑制（避免复位前自由变量导致的伪违例）。

两种方式提供里程碑：

**a) 手写/预生成的 milestone JSON 文件**

```bash
python3 -m main 10 designs/your_design.v --sv --strategy directed \
  --milestone-file milestones/your_design.json
```

milestone 文件格式：

```json
{
  "target": "人类可读的验证目标描述",
  "target_expr": "assertion 表达式（供 --coi 提取种子信号用，可留空）",
  "milestones": [
    {"step": 0, "description": "System Reset", "condition": "rst_n == 0", "expected_cycles": 10},
    {"step": 1, "description": "Reset deasserted", "condition": "rst_n == 1", "expected_cycles": 10}
  ]
}
```

`condition` 支持 `==`/`!=`/`&&`/`||`，`expected_cycles` 是从上一个里程碑到这个
里程碑预期需要的周期数（用作 BMC 边界，太保守会漏报，太宽松会变慢）。

**b) `--auto-plan`：让 LLM 从 assertion 自动生成里程碑**

```bash
export OPENAI_API_KEY=sk-...   # 或 ANTHROPIC_API_KEY / DEEPSEEK_API_KEY
python3 -m main 10 designs/your_design.v --sv --auto-plan \
  --llm-provider auto --explore_time 3600
```

- 引擎会先从设计里提取 assertion 作为验证目标，抽取相关 RTL 上下文喂给 LLM，
  让它生成一份里程碑序列（等价于上面的 JSON），然后自动切到 directed 策略。
- `--llm-provider`：`openai` / `anthropic` / `deepseek` / `auto`（默认按 API key
  前缀自动识别，`sk-ant-...` → anthropic，其余 `sk-...` → openai）。
- `--llm-base-url`：自定义 API 地址（比如 DeepSeek 用 `https://api.deepseek.com`）。
- `--mock`：不真的调用 LLM，用硬编码的假响应（调试/测试用）。
- 没有多个不相关的 assertion 目标时效果最好——如果设计里有多个 assertion，
  引擎只会用第一个生成里程碑，其余会被忽略（日志里会提示）。

**directed 策略的两个可调参数（消融实验用，一般不需要碰）：**

- `--no-eager-target-eval`：关闭"提前检查最终里程碑是否已经可 SAT"的抢先剪枝
- `--no-sliding-window`：关闭"跳过疑似幻觉里程碑"的滑动窗口逻辑

### 3. Value prediction（寄存器值预测，无里程碑）

```bash
python3 -m main 4 designs/test-designs/test_vp_fsm.v --sv --value_predict \
  --explore_time 60
```

适用场景：**没有** milestone 文件、**没有**开 `--auto-plan`——只是想让搜索更聪明
地朝可能触发 assertion 的方向走，而不是纯盲搜。原理（thesis §4.2）：在每个周期
结束时，根据当前寄存器的（symbolic）取值和排队中的 NBA 更新，静态预测下一周期
每个分支条件会走哪条边（forced_true / forced_false / free），用来调整下一步优先
探索哪条路径；但不会因为预测而丢弃任何路径——完备性不受影响。

跑完会额外打印一段统计：

```
[ValuePredict] ===== summary =====
[ValuePredict] prediction attempts: 3
[ValuePredict] branch predictions:  15
[ValuePredict]   forced_true:  3
[ValuePredict]   forced_false: 9
[ValuePredict]   free:         3
[ValuePredict] forced (prunable) ratio: 80.0%
[ValuePredict] path selections guided:   0
[ValuePredict] ===================
```

- `forced (prunable) ratio` 越高，说明这个设计的分支越多是由跨周期寄存器状态
  决定的（典型如 FSM），value prediction 收益越大。
- 这个模式没有里程碑门控：cycle 0 上出现的违例会被当作"自由输入触发的伪违例"
  抑制掉，cycle > 0 之后任何真实违例都会立刻上报。

**已知限制**：`_execute_cycle` 里对每个分支点的 fork 数量硬编码上限
`_MAX_FORK_ALTS=4`（`engine/strategies.py`）。如果某个分支点的 CFG 路径数超过 5
（比如一个 14 路径的 FSM 分支），只有 4 条会被继续探索，其余会被永久丢弃，可能
导致漏报。这是一个已知的预置问题，目前和 value-predict 模式共享，尚未修复；
如果怀疑漏报，可以对比一下 `--strategy blind`（穷举，不受这个上限影响）的结果。

`--value_predict` 也可以叠加在有里程碑的场景上使用，但**必须真正加载到至少一个
里程碑**（`--milestone-file` 指向的文件里 `milestones` 非空，或 `--auto-plan`
成功生成了里程碑）才会生效——此时引擎会用
`MilestoneDirectedStrategy(enable_value_prediction=True, ...)` 重新构造策略，
值预测辅助路径选择，里程碑门控逻辑照常生效。

注意：**单独写 `--strategy directed --value_predict` 而不给 `--milestone-file`
也不加 `--auto-plan` 是没有意义的**——这会构造一个空里程碑列表的
`MilestoneDirectedStrategy`，`enable_value_prediction` 实际上还是 `False`
（依赖分析会白跑一次，但预测器从未被启用）。这种"无里程碑"场景应该用上面第 3
节的纯 `--value_predict`（不加 `--strategy directed`），会自动选中
`ValuePredictDirectedStrategy`。

## Cone of Influence（COI）剪枝

```bash
python3 -m main 10 designs/large_design.v --sv --strategy directed \
  --milestone-file milestones/target.json --coi
```

对于有很多模块实例的大设计，`--coi` 会先从 assertion（或 milestone 文件的
`target_expr`/各级 `condition`）提取种子信号，反向分析哪些模块实例真正影响到
目标信号，把无关实例的 CFG 直接置空、从 `names_list` 中剔除，减少要探索的路径数。
milestone 文件里的信号名**必须带层级前缀**（如 `or1200_cpu.wb_pc`），裸信号名
（没有 `.` 分隔符）会被 COI 直接忽略，达不到剪枝效果。

## Redis 缓存 Z3 查询结果

```bash
redis-server &   # 确保本机 6379 端口有 redis 在跑
python3 -m main 10 designs/your_design.v --sv --strategy directed \
  --milestone-file milestones/your_design.json --use_cache --explore_time 3600
```

`--use_cache` 会把每次 Z3 求解的约束字符串作为 key 缓存结果，重复出现的约束
（比如同一个 reset 条件在不同 fork 分支里反复检查）直接查缓存，跳过 Z3 调用。
适合长跑、约束重复率高的场景（配合 directed/value-predict 策略跑较多周期数）；
小设计/短周期数/blind 模式下用不上，反而多一次 Redis IO。

## 其他常用选项

| 选项 | 作用 |
|---|---|
| `-t` / `--top` | 指定顶层模块名（默认自动探测） |
| `-I` / `--include` | 增加 include 搜索路径（可重复传） |
| `-B` / `--debug` | 打开调试输出 |
| `--explore_time <秒>` | 探索超时（超时后打印 `Execution time limit exceeded` 并退出） |
| `-v` / `--version` | 打印版本/用法信息 |

## `scripts/` 目录里的示例脚本

`scripts/` 下是几个针对 `designs/or1200/or1200_top.v` 的历史示例脚本（探索、
带缓存/不带缓存、assertion 检查等），可以参考里面的参数组合，但注意它们引用
的 `--check_assertions`/`--use_merge_queries` 选项在当前 `main.py` 里已不存在，
跑之前需要按上面的选项表调整。

## 输出怎么读

- `[Run] <module>/cfg<N>/path<M> (<K> blocks)...` / `[Exec] ...`：正在执行哪个模块
  哪个 CFG 的哪条路径
- `[Fork] <module>/cfg<N>: X/Y alternatives forked ...`：这个分支点有 Y 条替代
  路径，实际 fork 了 X 条进入待探索队列（如果被 `(capped)` 标注，说明触发了
  上面提到的 `_MAX_FORK_ALTS` 上限）
- `[Skip] ... abandoned/ignore`：这条路径的约束 UNSAT 或被引擎主动放弃，回滚状态
- `[Pruned] cycle N: UNSAT after execution`：整个周期执行完后路径条件不可满足
- `[Suppressed]` / `[Unconditional]` / `[Deferred Violation]`：assertion 违例的
  抑制/立即上报/延迟上报逻辑（directed / value-predict 两种策略各自的门控规则，
  见上文对应小节）
- 最终的 `Assertion violation detected!` 后面跟着按 cycle 分组的反例赋值表

## 架构简述

- `engine/execution_engine.py`：整体编排入口，`execute_sv()` 负责解析、
  CFG 构建、依赖分析、策略选择与 `strategy.run(...)` 调用
- `engine/cfg.py`：把 PySlang AST 转成 CFG，用 NetworkX 枚举所有简单路径
- `engine/strategies.py`：三种探索策略
  - `BlindSearchStrategy`：笛卡尔积穷举
  - `_DirectedSearchBase`：`MilestoneDirectedStrategy` 和
    `ValuePredictDirectedStrategy` 共享的基类（comb 求值/缓存、端口传播、
    值预测基础设施、CFG 路径执行、反例格式化等）
  - `MilestoneDirectedStrategy`：里程碑门控的优先队列搜索
  - `ValuePredictDirectedStrategy`：无里程碑、纯值预测驱动的优先队列搜索
- `engine/value_predictor.py`：多周期寄存器值预测器（thesis §4.2）
- `engine/milestone.py`：里程碑解析、打分、滑动窗口逻辑
- `frontend/dep_analyzer.py`：为值预测提供的静态依赖分析
- `frontend/coi_analyzer.py`：Cone of Influence 分析
- `frontend/llm_planner.py`：`--auto-plan` 用到的 LLM 调用封装
- `helpers/slang_helpers.py` / `helpers/rvalue_to_z3.py`：PySlang AST → Z3
  表达式转换、语句执行

更详细的内部实现说明见 `CLAUDE.md`。
