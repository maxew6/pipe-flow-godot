import sys, os, json, importlib
sys.path.insert(0, os.path.dirname(__file__))
import designer as D, pipemodel as P

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))


def build(mod_name, out_name, verbose=True):
    mod = importlib.import_module(mod_name)
    entries, metrics = [], []
    for level in mod.levels():
        built = level.build()
        m = D.metrics_for(level, built)
        entries.append(D.level_json(level, built, mod.CHAPTER, mod.DIFFICULTY))
        metrics.append(m)
        if verbose:
            print('\n=== Level %d  "%s"  %dx%d  par %d  solutions %d  score %.1f  seed %d' % (level.id, level.title, level.cols, level.rows, m['par'], m['solution_count'], m['difficulty_score'], m['seed']))
            print('start:'); print(D.ascii_board(built['start']))
            print('solution:'); print(D.ascii_board(built['solution']))
    data = {'format': 2, 'chapter': mod.CHAPTER, 'name': mod.NAME, 'difficulty': mod.DIFFICULTY, 'levels': entries}
    path = os.path.join(ROOT, 'data', 'levels', out_name)
    with open(path, 'w') as f:
        f.write('{\n  "format": 2,\n  "chapter": %d,\n  "name": %s,\n  "difficulty": %s,\n  "levels": [\n' % (mod.CHAPTER, json.dumps(mod.NAME), json.dumps(mod.DIFFICULTY)))
        for i, e in enumerate(entries):
            f.write('    ' + json.dumps(e, separators=(', ', ': ')) + (',\n' if i < len(entries) - 1 else '\n'))
        f.write('  ]\n}\n')
    return entries, metrics


if __name__ == '__main__':
    entries, metrics = build(sys.argv[1], sys.argv[2], verbose=('-q' not in sys.argv))
    json.dump(metrics, open('/home/claude/chapter_metrics.json', 'w'), indent=1)
    print('\nwrote', len(entries), 'levels')
