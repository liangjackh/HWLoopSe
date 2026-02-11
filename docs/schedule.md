太棒了，有四月中旬这个明确的 Deadline（死线），我们的规划就可以非常倒推和具体了。

从现在（2月初）到4月中旬大约有 **10周** 的时间。对于一篇顶会/顶刊级别的论文，这个时间窗口是 **“紧凑但可行”** 的（Tight but Doable）。

为了确保你不错过截稿日期，我根据我们刚刚确定的技术路线（LLM 前端 + 策略模式后端），为你生成了一份**“倒排日程表”**。

---

### 📅 投稿冲刺日程表 (Target: Mid-April)

**核心策略**：代码先行，数据为王。前 4 周必须把实验跑通，后 4 周专注于论文打磨。

#### 第一阶段：核心功能开发 (Foundation) —— [2月7日 - 2月20日]

*目标：让引擎跑起来，不仅能跑 `test_2.v`，还能跑简单的 RISC-V 模块。*

* **Week 1 (2.7 - 2.13): 后端重构 Sprint**
* **Day 1-2**: 完成 `strategies.py` 和 `ExecutionEngine` 的解耦（Strategy Pattern）。
* **Day 3-4**: 实现 `MilestoneManager` 和 `PriorityQueue` (Min-Heap) 逻辑。
* **Day 5-7**: 调试 `test_2.v`，确保**Mock Mode**下，定向搜索能秒解 Bug。


* **Week 2 (2.14 - 2.20): 前端 Agent Sprint**
* **Day 1-3**: 实现 `ContextSlicer` (利用 `pyslang` 提取源码) 和 `LLMPlanner`。
* **Day 4-5**: 对接 Claude/GPT-4 API，调试“幻觉校验”闭环（Self-Correction Loop）。
* **Day 6-7**: 联调。运行 `python main.py --auto-plan --target "..."`，实现全自动流程。



#### 第二阶段：实验与数据收集 (Experiments) —— [2月21日 - 3月10日]

*目标：拿到论文的核心数据（Tables & Charts）。这是论文能否录用的关键。*

* **Week 3 (2.21 - 2.27): Benchmark 适配**
* **任务**: 将 `properties_19.md` 中提到的 **Ariane (CVA6) CPU** 代码导入环境。
* **重点**: 挑选 3-5 个最具代表性的 Bug（如 `P1: CLINT access`，`P7: SATP Leak`）。
* **动作**: 为这些 Bug 编写 Driver 和 Stub（如果需要），确保静态解析器能跑通。


* **Week 4 (2.28 - 3.6): 对比实验 (Ablation Study)**
* **Baseline**: 运行旧的 `BlindSearchStrategy`，记录时间/内存/是否超时（肯定会超时）。
* **Ours**: 运行新的 `MilestoneDirectedStrategy`，记录时间/内存/生成的路径长度。
* **分析**: 收集数据点：`Speedup` (加速比), `Coverage` (覆盖率)。


* **Week 5 (3.7 - 3.10): 图表绘制**
* 绘制“随着时间推移的覆盖率增长图”（Milestone vs Blind）。



#### 第三阶段：论文撰写 (Writing) —— [3月11日 - 3月31日]

*目标：完成一篇逻辑严密、英语地道的 Full Paper。*

* **Week 6 (3.11 - 3.17): 骨架与方法论**
* 撰写 **Methodology** 章节：把我们定义的 `ContextSlicer`, `AutoPlanner`, `PriorityQueue` 画成架构图（Figure 1）。这是你最熟悉的，先写。


* **Week 7 (3.18 - 3.24): 实验与分析**
* 撰写 **Evaluation** 章节：填入 Week 4 收集的数据。重点强调：*“如果没有 LLM 指导，传统符号执行在 X 分钟内无法触达深层 Bug。”*


* **Week 8 (3.25 - 3.31): 引言与相关工作**
* 撰写 **Introduction** 和 **Related Work**（引用 Intel SylQ, KLEE, etc.）。
* **Abstract** 打磨。



#### 第四阶段：润色与投稿 (Polish & Submit) —— [4月1日 - 4月14日]

*目标：零错误，完美格式。*

* **Week 9 (4.1 - 4.7): 内部评审**
* 自己 Review 或者找同学看。检查逻辑漏洞。
* **格式检查**: 确保符合会议的 LaTeX 模板（双栏/单栏，页数限制）。


* **Week 10 (4.8 - 4.14): 最终冲刺**
* Check 拼写、参考文献格式。
* **4月14日**: 提交！🎉



---

### 💡 给你的特别建议

1. **利用好 `properties_19.md**`:
这个文件是你论文的**金矿**。不要只跑 `test_2.v`。审稿人想看的是**真实的硬件 Bug**。如果你能复现 Ariane 里的 `P1` 或 `P7`，论文录用率会翻倍。
2. **Mock Mode 的战略意义**:
在 Week 3 适配 Benchmark 时，如果 LLM 生成的路标不稳定，**先手动写死路标 (Mock Mode)** 跑通实验。论文里可以说“我们展示了基于里程碑的方法是有效的（Manual/Auto）”，不要因为 Prompt 调优卡住而耽误了实验数据的收集。
3. **保持代码整洁**:
现在重构的代码（Strategy Pattern）非常适合开源。如果论文中能附上 GitHub 链接（Anonymous 模式），会是巨大的加分项。

祝你投稿顺利！现在，让我们先把刚才定义的 `claude_frontend.md` 发给 Claude，开始 Week 1 的工作吧！