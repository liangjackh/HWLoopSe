这份指南旨在解决当前 MilestoneDirectedStrategy 中 Suppression 机制过于僵化导致真实 Bug 被误杀（Timeout/UNSAT）的问题。我们通过引入“语义放行”、“停滞检测”和“终极兜底”三级机制，确保引擎在处理如 p5 和 p13 这类 Bug 提前触发的 Case 时表现稳健。
🛠️ 任务规范：优化 Suppression 机制与增加延迟违例恢复

1. 目标
修复 Suppression 机制导致的超时问题。当前机制要求 milestones_completed >= total - 1 才能报告违例，这在 LLM 规划冗余或 Bug 提前出现时会导致引擎压制真实 Bug 直到超时。

2. 核心修改逻辑 (三级策略)

    一级：语义匹配放行：如果当前 Violation 的表达式包含 manager.target_expr，且已脱离复位阶段（cycle > 0），则直接报告。

    二级：启发式停滞释放：如果已保存 _deferred_violation 且满足以下任一条件，则释放：

        milestones_completed >= total_milestones - 2 (放宽阈值)。

        在当前 Milestone 深度停滞了超过 3 个 Cycle (Cycle 老化)。

        在当前 Milestone 深度停滞了超过 50 条路径 (Queue 停滞)。

    三级：终极兜底：在 run() 循环结束（Queue 耗尽或 Timeout）前，如果存在 _deferred_violation，将其作为最终结果报告。

3. 具体修改步骤

    Step 1: 修改 engine/execution_manager.py

        在 ExecutionManager 初始化中增加状态追踪变量：

            self.best_deferred_violation = None (存储格式：(assertions, state, progress))

            self.best_deferred_cycle = -1

            self.highest_milestone_seen = 0

            self.stagnation_counter = 0 (用于统计路径停滞)

    Step 2: 修改 engine/strategies.py 中的 _execute_cycle 方法

        定位 if result == "VIOLATION": 逻辑块。

        实现一级放行：通过字符串匹配或 AST 检查 violated_assertions 是否包含 manager.target_expr。

        优化记录逻辑：当决定 Suppress 时，如果当前 milestones_completed >= highest_milestone_seen，更新 best_deferred_violation 和对应的 cycle。

        重置停滞计数：如果 milestones_completed 有增长，重置 manager.stagnation_counter = 0。

    Step 3: 修改主搜索循环 (通常在 main.py 或 ExecutionEngine.run)

        在弹出路径处理前，增加 二级释放检查：
        Python

        if manager.best_deferred_violation and (
            current_cycle >= manager.best_deferred_cycle + 3 or 
            manager.stagnation_counter >= 50
        ):
            return "VIOLATION", manager.best_deferred_violation[2]

        在循环外层增加 try...except TimeoutException 或 if queue.empty() 后的 三级兜底逻辑：

            检查 manager.best_deferred_violation 是否非空，若非空则返回该违例。

4. 预期行为

    p5: milestones=1/3 时触发 total-2 逻辑或 Target 匹配逻辑，直接报告。

    p13: milestones=2/5 时虽然不满足 total-2，但通过 Target 匹配或 3 周期停滞逻辑释放。

    虚假 Bug: Cycle 0 或未完成 Reset 的报错依然会被压制，确保低误报。
