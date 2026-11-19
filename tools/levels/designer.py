"""Level design toolkit for the PIPE FLOW campaign (offline).

A level is authored as a SOLUTION: a tank->tap route, optional branches that end in caps, optional
'lure' paths (decoy pipes that start out lined up like a tempting but wrong route) and decoy fill.
A seeded scrambler then turns the pipes to create the starting puzzle. Every candidate start is checked
with the exact rule port (pipemodel.py) and only accepted if it satisfies the level's design targets
(unique/limited solutions, par range, not already solved). Output is fully deterministic."""
import json, math, random, os
import pipemodel as P

N, E, S, W = 0, 1, 2, 3
NAME = 'NESW'


def piece_for(mask):
    """(type, rotation) whose openings are exactly `mask`."""
    n = bin(mask).count('1')
    t = {1: 'C', 2: None, 3: 'T', 4: 'X'}[n] if n != 2 else ('I' if mask in (5, 10) else 'L')
    for r in range(4):
        if P.mask_of(t, r) == mask:
            return t, r
    raise ValueError('no piece for mask %d' % mask)


def dir_between(a, b):
    d = (b[0] - a[0], b[1] - a[1])
    return P.VEC.index(d)


class LevelDef:
    def __init__(self, id, title, hint, cols, rows, src_y, sink_y, seed, wrong=0.85, min_wrong=1,
                 solutions=(1, 1), par=(1, 99), tags=(), types='IL', density=0.0, move_limit=None):
        self.id, self.title, self.hint = id, title, hint
        self.cols, self.rows, self.src_y, self.sink_y = cols, rows, src_y, sink_y
        self.seed, self.wrong, self.min_wrong = seed, wrong, min_wrong
        self.solutions, self.par_range, self.tags = solutions, par, list(tags)
        self.types, self.density = types, density
        self.move_limit = move_limit
        self.open = {}            # network cell -> mask (intended route + branches)
        self.lures = {}           # decoy cells aligned in the starting state -> mask
        self.alts = {}            # decoy cells forming an alternative route (rotation scrambled) -> mask
        self.explicit = {}        # decoy cell -> type
        self.src = (0, src_y)
        self.sink = (cols - 1, sink_y)

    # --- authoring -----------------------------------------------------------
    def _link(self, table, a, b):
        d = dir_between(a, b)
        table[a] = table.get(a, 0) | (1 << d)
        table[b] = table.get(b, 0) | (1 << ((d + 2) % 4))

    def route(self, cells):
        assert cells[0] == self.src and cells[-1] == self.sink, (self.id, 'route must run tank->tap')
        self.open[cells[0]] = self.open.get(cells[0], 0) | (1 << W)
        self.open[cells[-1]] = self.open.get(cells[-1], 0) | (1 << E)
        for a, b in zip(cells, cells[1:]):
            self._link(self.open, a, b)
        return self

    def branch(self, frm, cells):
        """A spur from an existing network cell; its last cell becomes an end cap."""
        assert frm in self.open
        prev = frm
        for c in cells:
            self._link(self.open, prev, c)
            prev = c
        return self

    def lure(self, cells, bait=None):
        """Decoy pipes lined up like a tempting route. `bait` is the network cell the lure's first pipe
        points at: it must be a corner or tee that CAN turn toward it, otherwise the lure is harmless."""
        for a, b in zip(cells, cells[1:]):
            self._link(self.lures, a, b)
        first, last = cells[0], cells[-1]
        if bait is not None:
            self.lures[first] = self.lures.get(first, 0) | (1 << dir_between(first, bait))
        else:
            self.lures[first] = self.lures.get(first, 0) | (1 << ((dir_between(first, cells[1]) + 2) % 4))
        self.lures[last] = self.lures.get(last, 0) | (1 << ((dir_between(last, cells[-2]) + 2) % 4))
        return self

    def alt(self, cells):
        for a, b in zip(cells, cells[1:]):
            self._link(self.alts, a, b)
        return self

    def decoy(self, x, y, t):
        self.explicit[(x, y)] = t
        return self

    # --- build ---------------------------------------------------------------
    def solution_pieces(self):
        pieces = {c: piece_for(m) for c, m in self.open.items()}
        for c, m in self.lures.items():
            assert c not in pieces, (self.id, 'lure overlaps network', c)
            pieces[c] = piece_for(m)
        return pieces

    def attempt(self, attempt):
        rng = random.Random(self.seed * 1000 + attempt)
        net = self.solution_pieces()
        cells = {}
        for y in range(self.rows):
            for x in range(self.cols):
                c = (x, y)
                if c in self.open:
                    t, r = net[c]
                    cells[c] = (t, r)
                elif c in self.lures:
                    cells[c] = net[c]
                elif c in self.alts:
                    t, _ = piece_for(self.alts[c])
                    cells[c] = (t, rng.randrange(4))
                elif c in self.explicit:
                    cells[c] = (self.explicit[c], rng.randrange(4))
                elif rng.random() < self.density:
                    cells[c] = (rng.choice(self.types), rng.randrange(4))
                else:
                    cells[c] = ('.', 0)
        sol = P.Board(self.cols, self.rows, cells, self.src, self.sink)
        # scramble the network pieces
        start = sol.copy()
        turnable = [c for c in self.open if net[c][0] in P.ROTATABLE]
        rng.shuffle(turnable)
        want_wrong = max(self.min_wrong, math.ceil(self.wrong * len(turnable)))
        wrong_count = 0
        for c in turnable:
            t, r = net[c]
            goal = P.mask_of(t, r)
            options = [rr for rr in range(4) if P.mask_of(t, rr) != goal]
            if wrong_count < want_wrong and options:
                start.cells[c] = (t, rng.choice(options))
                wrong_count += 1
        return sol, start

    def build(self, max_attempts=600):
        for attempt in range(max_attempts):
            sol, start = self.attempt(attempt)
            if P.solve(start)['valid']:
                continue
            nets, truncated = P.enumerate_networks(start, limit=5000)
            if not nets or truncated:
                continue
            lo, hi = self.solutions
            if not (lo <= len(nets) <= hi):
                continue
            scored = sorted(((P.network_cost(start, n), sorted(n.items())) for n in nets))
            best_cost = scored[0][0]
            if not (self.par_range[0] <= best_cost <= self.par_range[1]):
                continue
            best = next(n for n in nets if sorted(n.items()) == scored[0][1])
            final = P.apply_network(start, best)
            assert P.solve(final)['valid'], (self.id, 'search result failed the solver')
            for n in nets:                                   # every enumerated network must pass the real rule
                assert P.solve(P.apply_network(start, n))['valid'], (self.id, 'enumerated network invalid')
            return dict(start=start, solution=final, nets=nets, par=best_cost, attempt=attempt, costs=sorted(c for c, _ in scored))
        raise RuntimeError('level %d: no start state met the design targets in %d attempts' % (self.id, max_attempts))


def metrics_for(level, built):
    start, sol = built['start'], built['solution']
    nets = built['nets']
    net_cells = set(level.open)
    best_net = {c: P.mask_of(*sol.cells[c]) for c in net_cells} if True else {}
    types = [sol.cells[c][0] for c in net_cells]
    common = set(nets[0].items())
    for n in nets[1:]:
        common &= set(n.items())
    decisions = set()
    for n in nets:
        for c, m in n.items():
            if nets[0].get(c) != m:
                decisions.add(c)
        decisions |= set(n) ^ set(nets[0])
    wrong = sum(1 for c in net_cells if P.mask_of(*start.cells[c]) != P.mask_of(*sol.cells[c]))
    decoys = sum(1 for c, (t, _) in start.cells.items() if t != '.' and c not in net_cells)
    paths = P.plausible_paths(start)
    # starting-state "false leads": decoy pieces whose opening already meets a route piece
    false_leads = 0
    for c in net_cells:
        m = P.mask_of(*start.cells[c])
        for d in range(4):
            if m & (1 << d):
                n = (c[0] + P.VEC[d][0], c[1] + P.VEC[d][1])
                if n in start.cells and n not in net_cells and start.cells[n][0] != '.' and start.mask(n) & (1 << ((d + 2) % 4)):
                    false_leads += 1
    score = (0.45 * built['par'] + 0.5 * len(net_cells) + 2.0 * types.count('T') + 3.0 * types.count('X')
             + 1.6 * types.count('C') + 0.3 * decoys + 1.8 * math.log2(paths + 1) + 1.5 * false_leads
             + (2.0 if level.lures else 0.0))
    return dict(id=level.id, cells=level.cols * level.rows, network_cells=len(net_cells), decoys=decoys,
                elbows=types.count('L'), straights=types.count('I'), tees=types.count('T'), crosses=types.count('X'),
                caps=types.count('C'), par=built['par'], solution_count=len(nets), solution_costs=built['costs'][:6],
                critical_cells=len(common), decision_cells=len(decisions), plausible_paths=paths,
                wrong_at_start=wrong, false_leads=false_leads, has_lure=bool(level.lures),
                difficulty_score=round(score, 1), seed=level.seed * 1000 + built['attempt'])


def level_json(level, built, chapter, difficulty):
    start, sol = built['start'], built['solution']
    out = {
        'id': level.id, 'chapter': chapter, 'difficulty': difficulty, 'title': level.title, 'hint': level.hint,
        'cols': level.cols, 'rows': level.rows,
        'source': {'x': level.src[0], 'y': level.src[1], 'side': 'W'},
        'sink': {'x': level.sink[0], 'y': level.sink[1], 'side': 'E'},
        'grid': start.to_rows(), 'solution': sol.to_rows(),
        'par': built['par'], 'expected': 'valid', 'solution_count': len(built['nets']),
        'tags': level.tags, 'seed': level.seed * 1000 + built['attempt'],
    }
    if level.move_limit:
        out['move_limit'] = level.move_limit
    return out


def ascii_board(b):
    lines = []
    for y in range(b.rows):
        lines.append('  ' + ' '.join(('..' if b.cells[(x, y)][0] == '.' else '%s%d' % b.cells[(x, y)]) for x in range(b.cols)))
    return '\n'.join(lines)
