"""Python port of the PIPE FLOW rules, used ONLY by the offline level tools.
It mirrors scripts/core/{direction,pipe_defs,board_model,flow_solver}.gd (sealed-network rule included).
The shipped game never uses this file: every level is ALSO validated at load time by the real GDScript
solver (LevelLoader.validate_level) and by tests/test_runner.gd. Run tools/verify/solver_mirror.py to see
the mirror agree with the documented rule cases.

Directions: N=0 E=1 S=2 W=3. Masks: bit d = side d open. Source tank on the W side of the source cell,
tap on the E side of the sink cell. Tokens: '.' empty, I straight, L elbow, T tee, X cross, C cap + rotation digit."""
from collections import deque

VEC = [(0, -1), (1, 0), (0, 1), (-1, 0)]
BASE = {'.': 0, 'I': 5, 'L': 3, 'T': 7, 'X': 15, 'C': 1}
ROTATABLE = set('ILTC')          # '.' and 'X' ignore taps


def rot(mask, turns):
    for _ in range(turns % 4):
        mask = ((mask << 1) | (mask >> 3)) & 15
    return mask


def mask_of(t, r):
    return rot(BASE[t], r)


def distinct_masks(t):
    seen = {}
    for r in range(4):
        seen.setdefault(mask_of(t, r), r)
    return [(m, r) for m, r in seen.items()]


def taps_between(t, r_from, mask_to):
    """Fewest clockwise taps turning piece type t (currently at rotation r_from) into mask_to; None if impossible."""
    if t not in ROTATABLE:
        return 0 if mask_of(t, r_from) == mask_to else None
    for k in range(4):
        if mask_of(t, (r_from + k) % 4) == mask_to:
            return k
    return None


class Board:
    def __init__(self, cols, rows, cells, src, sink):
        self.cols, self.rows, self.cells, self.src, self.sink = cols, rows, dict(cells), src, sink

    @staticmethod
    def from_rows(rows, src, sink):
        cells = {}
        for y, line in enumerate(rows):
            for x, tok in enumerate(line.split()):
                cells[(x, y)] = ('.', 0) if tok == '.' else (tok[0], int(tok[1]))
        return Board(len(rows[0].split()), len(rows), cells, src, sink)

    def to_rows(self):
        out = []
        for y in range(self.rows):
            out.append(' '.join('.' if self.cells[(x, y)][0] == '.' else '%s%d' % self.cells[(x, y)] for x in range(self.cols)))
        return out

    def inside(self, c):
        return 0 <= c[0] < self.cols and 0 <= c[1] < self.rows

    def mask(self, c):
        t, r = self.cells[c]
        return mask_of(t, r)

    def copy(self):
        return Board(self.cols, self.rows, self.cells, self.src, self.sink)


def solve(b):
    """Same contract as FlowSolver.solve: valid == tap reached AND no reachable open end leaks."""
    res = dict(valid=False, reached=False, source_connected=False, sink_wet=False, dead=[], order=[], failure='')
    if not (b.mask(b.src) & 8):
        res['failure'] = 'source_closed'
        return res
    res['source_connected'] = True
    seen = {b.src}
    queue = deque([b.src])
    while queue:
        c = queue.popleft()
        res['order'].append(c)
        if c == b.sink:
            res['sink_wet'] = True
        m = b.mask(c)
        for d in range(4):
            if not m & (1 << d):
                continue
            if c == b.src and d == 3:
                continue
            if c == b.sink and d == 1:
                res['reached'] = True
                continue
            n = (c[0] + VEC[d][0], c[1] + VEC[d][1])
            if b.inside(n) and b.mask(n) & (1 << ((d + 2) % 4)):
                if n not in seen:
                    seen.add(n)
                    queue.append(n)
            else:
                res['dead'].append((c, d))
    if res['reached']:
        res['failure'] = '' if not res['dead'] else 'leak'
        res['valid'] = not res['dead']
    else:
        res['failure'] = 'sink_closed' if res['sink_wet'] else 'no_route'
    return res


def enumerate_networks(b, limit=20000):
    """Every distinct sealed network (cell -> mask) that carries water from the tank to the tap.
    Cells outside the network keep their current rotation, so this is EXACT: a configuration is valid
    iff its reachable component is one of these networks."""
    results = []
    truncated = [False]

    def options(cell, need_dir):
        t = b.cells[cell][0]
        if t == '.':
            return []
        return [(m, r) for m, r in distinct_masks(t) if m & (1 << need_dir)]

    def rec(assign, queue):
        if len(results) >= limit:
            truncated[0] = True
            return
        if not queue:
            if b.sink in assign and assign[b.sink] & 2:
                results.append(dict(assign))
            return
        cell, queue = queue[0], queue[1:]
        pending = [d for d in range(4) if assign[cell] & (1 << d)]

        def step(assign, queue, pending):
            if not pending:
                rec(assign, queue)
                return
            d, rest = pending[0], pending[1:]
            if cell == b.src and d == 3:
                return step(assign, queue, rest)
            if cell == b.sink and d == 1:
                return step(assign, queue, rest)
            n = (cell[0] + VEC[d][0], cell[1] + VEC[d][1])
            if not b.inside(n) or b.cells[n][0] == '.':
                return                                   # leak
            need = (d + 2) % 4
            if n in assign:
                if assign[n] & (1 << need):
                    step(assign, queue, rest)
                return
            for m, _ in options(n, need):
                a2 = dict(assign)
                a2[n] = m
                step(a2, queue + [n], rest)

        step(assign, queue, pending)

    for m, _ in options(b.src, 3):
        rec({b.src: m}, [b.src])
    return results, truncated[0]


def network_cost(b, net):
    total = 0
    for c, m in net.items():
        t, r = b.cells[c]
        k = taps_between(t, r, m)
        if k is None:
            return None
        total += k
    return total


def apply_network(b, net):
    """Board with the network's cells turned (fewest taps) and everything else untouched."""
    out = b.copy()
    for c, m in net.items():
        t, r = b.cells[c]
        k = taps_between(t, r, m)
        out.cells[c] = (t, (r + k) % 4)
    return out


def plausible_paths(b, cap=200000):
    """Simple grid paths tank-cell -> tap-cell through non-empty tiles, ignoring orientation:
    a rough count of 'routes that look possible'."""
    count = [0]

    def dfs(c, seen):
        if count[0] >= cap:
            return
        if c == b.sink:
            count[0] += 1
            return
        for d in range(4):
            n = (c[0] + VEC[d][0], c[1] + VEC[d][1])
            if b.inside(n) and n not in seen and b.cells[n][0] != '.':
                seen.add(n)
                dfs(n, seen)
                seen.discard(n)

    dfs(b.src, {b.src})
    return count[0]
