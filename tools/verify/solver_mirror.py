import json
from collections import deque
VEC=[(0,-1),(1,0),(0,1),(-1,0)]; NAME='NESW'
BASE={'.':0,'I':5,'L':3,'T':7,'X':15,'C':1}
def rot(m,t):
    for _ in range(t%4): m=((m<<1)|(m>>3))&15
    return m
def parse(rows): return [[(c[0], int(c[1]) if len(c)>1 else 0) for c in r.split()] for r in rows]
def mask(g,x,y): k,r=g[y][x]; return rot(BASE[k],r)
def solve(g,src,sink):
    h=len(g); w=len(g[0]); sx,sy=src
    if not mask(g,sx,sy)&8: return dict(reached=False,dead=[],order=[],valid=False,why='source_closed')
    seen={(sx,sy)}; q=deque([(sx,sy)]); order=[]; reached=False; dead=[]
    while q:
        x,y=q.popleft(); order.append((x,y)); m=mask(g,x,y)
        for d in range(4):
            if not m&(1<<d): continue
            if (x,y)==(sx,sy) and d==3: continue
            if (x,y)==sink and d==1: reached=True; continue
            nx,ny=x+VEC[d][0],y+VEC[d][1]
            if 0<=nx<w and 0<=ny<h and mask(g,nx,ny)&(1<<((d+2)%4)):
                if (nx,ny) not in seen: seen.add((nx,ny)); q.append((nx,ny))
            else: dead.append(((x,y),NAME[d]))
    return dict(reached=reached,dead=dead,order=order,valid=reached and not dead,why='')

import os, json
HERE = os.path.dirname(os.path.abspath(__file__))
import glob
LEVEL_FILES = sorted(glob.glob(os.path.join(HERE, '..', '..', 'data', 'levels', 'chapter_*.json')))


def run(name, rows, src, sink, expect_reached, expect_valid, expect_dead=None):
    g = parse(rows); r = solve(g, src, sink)
    ok = (r['reached'] == expect_reached) and (r['valid'] == expect_valid) and (expect_dead is None or r['dead'] == expect_dead)
    print(('OK  ' if ok else 'BAD ') + name, 'reached=%s valid=%s dead=%s' % (r['reached'], r['valid'], r['dead']))
    assert ok, name


levels = {l['id']: l for f in LEVEL_FILES for l in json.load(open(f))['levels']}
# the exact layout from the bug screenshots (it was Level 4 of the first campaign)
g = parse(["I1 T1 L2 L1", "I0 C0 I0 I1", "L1 I1 L0 L2", "I1 L0 I0 L0"])
print('Screenshot layout, cap turned correctly:', {k: v for k, v in solve(g, (0, 0), (3, 3)).items() if k != 'order'})
g[1][1] = ('C', 2)   # the screenshot state: the cap under the tee opens away from it
r = solve(g, (0, 0), (3, 3))
print('Screenshot state (cap C2):', {k: v for k, v in r.items() if k != 'order'})
print('  OLD rule (tap reachable => success):', 'ACCEPTED (the bug)' if r['reached'] else 'rejected')
print('  NEW rule (tap reachable AND sealed):', 'ACCEPTED' if r['valid'] else 'REJECTED, leak at %s side of cell %s' % (r['dead'][0][1], r['dead'][0][0]))
assert r['reached'] and not r['valid']

run('1 reciprocal openings', ["I1 I1"], (0, 0), (1, 0), True, True, [])
run('2 mismatched openings', ["I1 L1"], (0, 0), (1, 0), False, False, [((0, 0), 'E')])
run('3 reachable dead end', ["I1 T1 I1", "I1 I1 I1"], (0, 0), (2, 0), True, False, [((1, 0), 'S')])
run('4 open end facing empty cell', ["I1 T1 I1", ". L0 ."], (0, 0), (2, 0), True, False, [((1, 1), 'E')])
run('5 open end facing outside board', ["I1 T3 I1"], (0, 0), (2, 0), True, False, [((1, 0), 'N')])
run('6 correctly capped end', ["I1 T1 I1", ". C0 ."], (0, 0), (2, 0), True, True, [])
for crot in (1, 2, 3):
    run('7 cap rotated wrong C%d' % crot, ["I1 T1 I1", ". C%d ." % crot], (0, 0), (2, 0), True, False, [((1, 0), 'S')])
run('8 plain valid route', ["I1 I1 I1"], (0, 0), (2, 0), True, True, [])
run('9 tap reached + leaking branch', ["I1 T1 I1", ". L0 ."], (0, 0), (2, 0), True, False)
run('10 sealed cycle', ["I1 T1 L2", ". L0 T3"], (0, 0), (2, 1), True, True, [])
run('10b cycle with a leak', ["I1 T1 L2", ". T0 T3"], (0, 0), (2, 1), True, False)
for lid, L in levels.items():
    g = parse(L['solution']); s = L['source']; t = L['sink']
    assert solve(g, (s['x'], s['y']), (t['x'], t['y']))['valid'], lid
    wet = set(solve(g, (s['x'], s['y']), (t['x'], t['y']))['order'])   # caps the water reaches (decoy caps may sit in any rotation)
    for y, row in enumerate(g):
        for x, (k, rr) in enumerate(row):
            if k == 'C' and (x, y) in wet:
                for crot in range(4):
                    g2 = [list(r_) for r_ in g]; g2[y][x] = ('C', crot)
                    assert solve(g2, (s['x'], s['y']), (t['x'], t['y']))['valid'] == (crot == rr), (lid, x, y, crot)
print('All %d levels: solution valid and sealed; every cap the water reaches seals only in its stored rotation.' % len(levels))
