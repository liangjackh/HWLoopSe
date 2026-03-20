"""The Symbolic State is comprised of the path condition and the symbolic store. There
are some other methods here that may be helpful, too."""

import z3
from z3 import Solver, Int, BitVec, BitVecSort
import logging


class _LazyPC:
    """Thin wrapper that makes SymbolicState._pc_assertions look like a z3.Solver.

    Supports: add(), push()/pop(), check(), model(), assertions(), reset()
    push/pop are implemented with a stack of list snapshots — no real Solver
    is constructed until check() or model() is actually called.
    """
    __slots__ = ('_s', '_stack')

    def __init__(self, state):
        self._s = state
        self._stack = []

    def add(self, *args):
        from z3 import AstVector
        self._s._pc_solver = None   # invalidate cached solver
        for arg in args:
            if isinstance(arg, AstVector):
                self._s._pc_assertions.extend(arg)
            elif hasattr(arg, '__iter__') and not hasattr(arg, 'as_ast'):
                self._s._pc_assertions.extend(arg)
            else:
                self._s._pc_assertions.append(arg)

    def push(self):
        self._stack.append((
            list(self._s._pc_assertions),
            self._s.pc_constraint_set.copy(),
            self._s._pc_solver,   # save solver reference — valid for this assertion snapshot
        ))

    def pop(self):
        if self._stack:
            assertions, constraint_set, solver = self._stack.pop()
            self._s._pc_assertions = assertions
            self._s.pc_constraint_set = constraint_set
            self._s._pc_solver = solver   # restore instead of invalidate

    def check(self):
        return self._build_solver().check()

    def model(self):
        return self._build_solver().model()

    def assertions(self):
        return list(self._s._pc_assertions)

    def reset(self):
        self._s._pc_assertions = []
        self._s._pc_solver = None
        self._stack.clear()

    def _build_solver(self):
        if self._s._pc_solver is None:
            s = Solver()
            for a in self._s._pc_assertions:
                s.add(a)
            self._s._pc_solver = s
        return self._s._pc_solver


class SymbolicState:
    sort = BitVecSort(32)

    def __init__(self):
        self._pc_assertions = []   # plain Python list of Z3 ExprRef (cheap to copy)
        self._pc_solver = None     # lazily built Solver; invalidated on add/reset
        self.assertion_counter = 0
        self.clock_cycle = 0
        self.store = {}
        self.pending_nba = {}
        self.cond = False
        self.pc_constraint_set = set()
        self.pc = _LazyPC(self)    # stable instance — push/pop stack survives across accesses

    def apply_pending_nba(self):
        """Apply pending non-blocking assignments to the store.
        This should be called at the beginning of each new cycle."""
        if self.pending_nba:
            total = sum(len(updates) for updates in self.pending_nba.values())
            print(f"[NBA-APPLY] Applying {total} pending NBA(s)")
            logging.debug(f"[NBA] Applying {total} pending NBA(s)")
        for module_name, updates in self.pending_nba.items():
            if module_name not in self.store:
                self.store[module_name] = {}
            for var_name, value in updates.items():
                if 'valid_pipe' in var_name or 'in_a_history' in var_name:
                    print(f"[NBA-APPLY]   {module_name}.{var_name} <= {value}")
                logging.debug(f"[NBA]   {module_name}.{var_name} <= {value}")
                self.store[module_name][var_name] = value
        self.pending_nba = {}

    def add_pending_nba(self, module_name: str, var_name: str, value):
        """Add a non-blocking assignment to the pending queue."""
        if module_name not in self.pending_nba:
            self.pending_nba[module_name] = {}
        self.pending_nba[module_name][var_name] = value
        if 'valid_pipe' in var_name or 'in_a_history' in var_name:
            print(f"[NBA-QUEUE] {module_name}.{var_name} <= {value}")
        logging.debug(f"[NBA] Queued NBA: {module_name}.{var_name} <= {value}")

    def clone(self):
        """Efficient shallow clone. Safe because Z3 ExprRef values are immutable."""
        new_state = SymbolicState()
        new_state.assertion_counter = self.assertion_counter
        new_state.clock_cycle = self.clock_cycle
        new_state.cond = self.cond
        new_state.store = {mod: sigs.copy() for mod, sigs in self.store.items()}
        new_state.pending_nba = {mod: sigs.copy() for mod, sigs in self.pending_nba.items()}
        new_state.pc_constraint_set = self.pc_constraint_set.copy()
        # O(n) list copy — no Solver construction at all
        new_state._pc_assertions = list(self._pc_assertions)
        return new_state

    def get_symbolic_expr(self, module_name: str, var_name: str) -> str:
        """Just looks up a symbolic expression associated with a specific variable name
        in that particular module."""
        if '[' in var_name:
            name = var_name.split("[")[0]
            return self.store[module_name][name]
        elif '.' in var_name:
            real_module_name = var_name.split(".")[0]
            real_var_name = var_name.split(".")[1]
            return self.store[real_module_name][real_var_name]
        return self.store[module_name][var_name]

    def get_symbols(self):
        """Returns a list of all the symbols present in the symbolic state."""
        symbols_list = []
        for module in self.store:
            for signal in self.store[module]:
                symbolic_expression = self.store[module][signal]
                symbols_list += symbolic_expression.split(" ")
        res = []
        for sym in symbols_list:
            if sym.isalnum():
                res.append(sym)
        return res
