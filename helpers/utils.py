"""General utility functions used across the codebase"""
import random
import string


def to_binary(i: int, digits: int = 128) -> str:
    num: str = bin(i)[2:]
    padding_len: int = digits - len(num)
    return  ("0" * padding_len) + num 


def init_symbol() -> str:
    """Initializes signal with random symbol."""
    #TODO:change symbol length back to 16 or whatever or make this hash to guarantee good randomness
    return ''.join(random.choice(string.ascii_uppercase + string.ascii_lowercase + string.digits) for _ in range(16))


def topo_sort_nodes(node_ids, writes_of, reads_of):
    """Topologically sort nodes by write→read data dependency.

    If node A writes signal X and node B reads signal X, then A must come
    before B in the returned order. Falls back to the original ``node_ids``
    order when a dependency cycle is detected (combinational feedback).

    Args:
        node_ids: iterable of node identifiers (any hashable)
        writes_of: callable(node_id) -> set of written signal names
        reads_of:  callable(node_id) -> set of read signal names

    Returns:
        A list of node_ids in dependency order.
    """
    import networkx as nx

    node_ids = list(node_ids)
    if len(node_ids) <= 1:
        return node_ids

    signal_writers = {}   # signal_name -> [node_ids that write it]
    reads_cache = {}
    for nid in node_ids:
        for sig in writes_of(nid):
            signal_writers.setdefault(sig, []).append(nid)
        reads_cache[nid] = reads_of(nid)

    G = nx.DiGraph()
    G.add_nodes_from(node_ids)
    for nid in node_ids:
        for sig in reads_cache[nid]:
            for writer in signal_writers.get(sig, ()):
                if writer != nid:
                    G.add_edge(writer, nid)

    try:
        return list(nx.topological_sort(G))
    except nx.NetworkXUnfeasible:
        # Combinational cycle — preserve original order
        return node_ids


def build_symbol_to_signals(state):
    """Build a reverse map from symbol name -> list of "module.signal".

    A signal's store value is either a random symbol string (produced by
    init_symbol) or a Z3 expression whose leaves are such symbols. The Z3
    variable created for a symbolic signal is named exactly by that stored
    value, so ``str(value)`` gives the symbol name that appears in the path
    condition. Iterating the store therefore yields the inverse mapping needed
    to explain which signal each free variable in a violation came from.

    Returns:
        Dict[str, List[str]] mapping symbol name -> sorted unique "module.signal".
    """
    mapping = {}
    store = getattr(state, 'store', None)
    if not store:
        return mapping
    for module, sigs in store.items():
        if not isinstance(sigs, dict):
            continue
        for signal, value in sigs.items():
            key = str(value)
            mapping.setdefault(key, set()).add(f"{module}.{signal}")
    # Freeze to sorted lists for stable output
    return {k: sorted(v) for k, v in mapping.items()}


def collect_z3_symbols(expr, acc=None):
    """Recursively collect the names of free (uninterpreted) Z3 variables.

    Works on a single Z3 expression or an iterable of expressions. Falls back
    to returning an empty set for anything that is not a Z3 AST.
    """
    if acc is None:
        acc = set()

    # Allow passing a list/tuple of assertions
    if isinstance(expr, (list, tuple)):
        for e in expr:
            collect_z3_symbols(e, acc)
        return acc

    try:
        import z3
    except Exception:
        return acc

    if not isinstance(expr, z3.ExprRef):
        return acc

    try:
        # A free variable is a constant (0 children) with an uninterpreted decl.
        if expr.num_args() == 0 and expr.decl().kind() == z3.Z3_OP_UNINTERPRETED:
            acc.add(expr.decl().name())
            return acc
        for child in expr.children():
            collect_z3_symbols(child, acc)
    except Exception:
        pass
    return acc
