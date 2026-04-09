#  当前路径探索流程 (MilestoneDirectedStrategy)

##  整体架构

  execute_sv()  (execution_engine.py)
    ├── Step 1: 发现模块实例, 按 definition 分组
    ├── Step 2: 为每个 definition 构建 CFG (always块 → 基本块 → 路径)
    ├── Step 3: 为每个 instance 创建状态空间, 引用共享 CFG
    ├── Step 3.5: COI 剪枝 (根据 assertion 中的信号, 保留相关模块)
    ├── Step 4: 加载 milestones (从文件 或 LLM 生成)
    └── Step 5: strategy.run()  → MilestoneDirectedStrategy.run()

  MilestoneDirectedStrategy 主循环

  run() (strategies.py:349)
    ├── 初始化: _initialize_state() — 所有信号置0, 端口统一符号值, 组合逻辑求值
    ├── 创建初始 WorkItem(score, cycle=0, milestones=0, state)
    ├── 放入优先队列 (min-heap, score越小越优先)
    │
    └── while worklist 非空:
          ├── 弹出 score 最小的 WorkItem
          ├── BMC 剪枝: 如果 local_depth > expected_cycles + margin → 跳过
          ├── _execute_cycle() — 执行一个时钟周期
          │     ├── Step 1: 若 cycle>0, 应用 NBA (非阻塞赋值), 刷新主输入, 重算组合逻辑
          │     ├── Step 2: 构建本周期的 CFG 列表 (跳过 initial 块 if cycle>0)
          │     ├── Step 3: 顺序执行各 CFG:
          │     │     ├── 如果 CFG 有多条路径 → Lazy Fork:
          │     │     │     ├── 选一条"首选路径"执行 (cycle 0 走 reset 路径, cycle>0 走非 reset)
          │     │     │     └── 其余路径作为新 WorkItem 入队 (snapshot + score+1)
          │     │     ├── _execute_path() — 沿所选路径执行基本块
          │     │     ├── 如果 VIOLATION:
          │     │     │     └── 若未到最后一个 milestone 前 → 抑制 (可能是伪违例)
          │     │     └── 如果 abandon/ignore → 回滚该 CFG 的状态变更
          │     ├── Step 4: 重算组合逻辑
          │     ├── Step 5: SAT 检查 — UNSAT 则剪枝
          │     ├── Step 6: Milestone 检查:
          │     │     ├── check_final_milestone() — 若已到倒数第1步且最终 milestone SAT → VIOLATION
          │     │     ├── advance_with_sliding_window() — 推进 milestone 进度 (可跳过幻觉 milestone)
          │     │     └── 若全部 milestone 达成 → ALL_MILESTONES → 报告违例
          │     └── Step 7: 入队下一周期的 WorkItem(score=compute_score(), cycle+1)
          │
          └── 队列耗尽 → "Search exhausted (UNSAT)"

  关键概念

  - WorkItem: (score, cycle, milestones_completed, state, execution_context) — 优先队列中的一个探索状态
  - Lazy Fork: 遇到分支时不立即展开所有组合, 而是执行首选路径, 其余作为新 WorkItem 延迟入队
  - BMC 剪枝: 每个 milestone 有 expected_cycles, 如果从上一个 milestone 开始的局部深度超过 k + margin, 则认为该 milestone 可能是幻觉, 剪掉该路径
  - Score: compute_score_stateless() 基于 milestone 进度和周期数计算优先级, 越接近目标的路径越优先
  - Sliding Window: 允许跳过无法达成的中间 milestone, 避免被单个幻觉 milestone 卡死

  当前 hackdac18 的问题

  milestone 文件 p2.json 中 step 0-1 使用了 RST — 这个信号在设计中不存在, 实际的 reset 信号是 rstn_top。这是 LLM 生成 milestone 时的幻觉。因为 milestone 0
  永远无法满足, 所有16条路径都在 BMC 剪枝阶段被丢弃: local_depth=16 > bound m=15 (k=10+margin=5).
