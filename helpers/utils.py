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
