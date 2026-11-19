"""Independent campaign validator (offline). Re-reads data/levels/chapter_*.json from disk and re-checks
every level against the rule port; recomputes par as the TRUE minimum over every valid network; checks
schema, ids, titles and chapter ranges; writes docs/validation_report.json.
The same checks are done again at runtime by the real GDScript solver (LevelLoader.validate_level) and in
tests/test_runner.gd. Exit code 1 on any failure."""
import glob, json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import pipemodel as P, designer as D

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CHAPTERS = {1: ('easy', 1, 20), 2: ('medium', 21, 45), 3: ('hard', 46, 75), 4: ('extreme', 76, 100)}
REQUIRED = ['id', 'chapter', 'difficulty', 'title', 'hint', 'cols', 'rows', 'source', 'sink', 'grid', 'solution', 'par', 'expected']


def check_level(lv, errors):
    def err(msg):
        errors.append('level %s: %s' % (lv.get('id', '?'), msg))
    for k in REQUIRED:
        if k not in lv:
            err('missing field ' + k)
            return None
    diff, lo, hi = CHAPTERS[lv['chapter']]
    if lv['difficulty'] != diff:
        err('difficulty %s does not match chapter %d' % (lv['difficulty'], lv['chapter']))
    if not (lo <= lv['id'] <= hi):
        err('id outside chapter range %d-%d' % (lo, hi))
    if lv['expected'] != 'valid':
        err('expected must be "valid"')
    src = (lv['source']['x'], lv['source']['y']); snk = (lv['sink']['x'], lv['sink']['y'])
    if lv['source']['side'] != 'W' or lv['sink']['side'] != 'E' or src[0] != 0 or snk[0] != lv['cols'] - 1:
        err('source must be on column 0 / side W and sink on the last column / side E')
    start = P.Board.from_rows(lv['grid'], src, snk)
    sol = P.Board.from_rows(lv['solution'], src, snk)
    if (start.cols, start.rows) != (lv['cols'], lv['rows']) or (sol.cols, sol.rows) != (lv['cols'], lv['rows']):
        err('grid size does not match cols/rows')
        return None
    for c in start.cells:
        if start.cells[c][0] != sol.cells[c][0]:
            err('piece type differs between grid and solution at %s' % (c,))
    r_sol = P.solve(sol)
    if not r_sol['valid']:
        err('stored solution is NOT valid (%s, leaks %s)' % (r_sol['failure'], r_sol['dead']))
    if P.solve(start)['valid']:
        err('starting layout is already solved')
    taps = sum(P.taps_between(start.cells[c][0], start.cells[c][1], sol.mask(c)) or 0 for c in start.cells)
    nets, truncated = P.enumerate_networks(start, limit=20000)
    if truncated:
        err('solution search truncated; cannot prove par')
    best = min(P.network_cost(start, n) for n in nets) if nets else None
    if best is None:
        err('no valid configuration exists')
    elif lv['par'] != best:
        err('par %d is not the true minimum %d' % (lv['par'], best))
    if best is not None and taps != lv['par']:
        err('stored solution needs %d taps but par is %d' % (taps, lv['par']))
    if lv.get('solution_count') != len(nets):
        err('solution_count %s != searched %d' % (lv.get('solution_count'), len(nets)))
    for n in nets:                                           # every accepted solution must satisfy the real rule
        if not P.solve(P.apply_network(start, n))['valid']:
            err('a searched solution fails the solver')
            break
    if 'move_limit' in lv and lv['move_limit'] < lv['par']:
        err('move_limit below par')
    cells = lv['cols'] * lv['rows']
    return dict(id=lv['id'], title=lv['title'], chapter=lv['chapter'], size='%dx%d' % (lv['cols'], lv['rows']), cells=cells,
                par=lv['par'], solution_count=len(nets), solution_valid=r_sol['valid'], start_solved=P.solve(start)['valid'],
                par_is_true_minimum=(best == lv['par']), stored_solution_taps=taps)


def main():
    errors, results, titles, ids = [], [], set(), []
    files = sorted(glob.glob(os.path.join(ROOT, 'data', 'levels', 'chapter_*.json')))
    for f in files:
        data = json.load(open(f))
        for lv in data['levels']:
            if lv['title'] in titles:
                errors.append('duplicate title ' + lv['title'])
            titles.add(lv['title']); ids.append(lv['id'])
            res = check_level(lv, errors)
            if res:
                results.append(res)
    if ids != list(range(1, len(ids) + 1)):
        errors.append('level ids are not contiguous from 1: %s' % ids)
    report = dict(levels_checked=len(results), levels_valid=sum(1 for r in results if r['solution_valid'] and not r['start_solved'] and r['par_is_true_minimum']),
                  errors=errors, results=results)
    json.dump(report, open(os.path.join(ROOT, 'docs', 'validation_report.json'), 'w'), indent=1)
    print('files: %s' % [os.path.basename(f) for f in files])
    print('levels checked: %d   fully valid: %d   errors: %d' % (report['levels_checked'], report['levels_valid'], len(errors)))
    for e in errors:
        print('  ERROR', e)
    print('id title                 size  par sols')
    for r in results:
        print('%2d %-21s %-5s %3d %4d' % (r['id'], r['title'], r['size'], r['par'], r['solution_count']))
    sys.exit(1 if errors else 0)


if __name__ == '__main__':
    main()
