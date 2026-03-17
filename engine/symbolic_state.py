"""The Symbolic State is comprised of the path condition and the symbolic store. There
are some other methods here that may be helpful, too."""

import z3
from z3 import Solver, Int, BitVec, BitVecSort
import logging

class SymbolicState:
    sort = BitVecSort(32)

    def __init__(self):
        self.pc = Solver()
        self.assertion_counter = 0
        self.clock_cycle = 0
        self.store = {}
        self.pending_nba = {}
        self.cond = False
        self.pc_constraint_set = set()

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
        # Clear pending assignments after applying
        self.pending_nba = {}

    def add_pending_nba(self, module_name: str, var_name: str, value):
        """Add a non-blocking assignment to the pending queue."""
        if module_name not in self.pending_nba:
            self.pending_nba[module_name] = {}
        self.pending_nba[module_name][var_name] = value
        if 'valid_pipe' in var_name or 'in_a_history' in var_name:
            print(f"[NBA-QUEUE] {module_name}.{var_name} <= {value}")
        logging.debug(f"[NBA] Queued NBA: {module_name}.{var_name} <= {value}")

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
        """Returns a list of all the symbols present in the symbolic state.
        This is useful in the parsing to z3 phase because we need to know what symbols to declare as constants."""
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
