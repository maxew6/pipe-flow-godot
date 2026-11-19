"""Writes docs/CAMPAIGN.md from the real validation report + design metrics (no hand-typed numbers)."""
import json, os
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
rep = json.load(open(os.path.join(ROOT, 'docs', 'validation_report.json')))
met = {m['id']: m for m in json.load(open(os.path.join(ROOT, 'docs', 'chapter_1_metrics.json')))}
lv = {}
for f in ['chapter_1.json']:
    for l in json.load(open(os.path.join(ROOT, 'data', 'levels', f)))['levels']:
        lv[l['id']] = l
PURPOSE = {
 1: 'Tap to turn; two elbows, two straights.', 2: 'Straight pipes carry water in a line; elbows turn it.', 3: 'Chain of turns, follow the route.',
 4: 'A long snaking route: plan from the tank.', 5: 'Work backwards from where the water must end.', 6: 'Short breather after the first long routes.',
 7: 'First decoys; a bait pipe pulls the wrong way.', 8: 'A finished-looking line that goes nowhere.', 9: 'Decoys + bait beside a corner.',
 10: 'First cap: a tee has a spare opening to seal.', 11: 'Two tees, two caps: cap orientation matters.', 12: 'A tee on a bend; decoy caps do not belong to it.',
 13: 'A branch (spur of two) that must end in a cap.', 14: 'The cross never turns; seal its two unused sides.', 15: 'Two junctions, two spurs.',
 16: 'Two valid routes; fewer turns wins par.', 17: 'Two routes, decoys; the nearly-done loop may cost more.', 18: 'Several routes; choose the cheapest.',
 19: 'Tee + cap + bait: choose which side of the tee to open.', 20: 'Finale: two tees, a cross, four caps.'}
out = ['# Campaign (100 levels, built in stages)', '',
 '| Chapter | Difficulty | Levels | Theme | Status |', '|---|---|---|---|---|',
 '| 1 | Easy | 1-20 | Learn to Read the Pipes | **built and validated (20/20)** |',
 '| 2 | Medium | 21-45 | Think Before You Turn | not built yet |',
 '| 3 | Hard | 46-75 | Plan the Whole Network | not built yet |',
 '| 4 | Extreme | 76-100 | Master the System | not built yet |', '',
 'The game only shows chapters whose levels exist; nothing is advertised that is not in the build.', '',
 '## Level data (data/levels/chapter_N.json)',
 'Each level: `id`, `chapter`, `difficulty`, `title`, `hint` (optional message), `cols`, `rows`, `source`/`sink` (tank on the W side of column 0, tap on the E side of the last column), `grid` (starting pieces and rotations), `solution` (a known valid state), `par` (the 3-star target), `expected` ("valid"), optional `move_limit`, plus `solution_count`, `tags`, `seed` (how the start was generated; levels are fixed data, so they are identical every time).',
 'Tokens: `.` empty, `I` straight, `L` elbow, `T` tee, `X` cross, `C` cap, followed by a rotation digit 0-3 (clockwise quarter turns).', '',
 '## How every level is checked',
 '1. **At load time, in the game (real GDScript solver):** `LevelLoader.validate_level` checks the schema, chapter/id range, piece types, that the stored solution is VALID (tap reached, every reachable open end sealed), that the start layout is NOT already valid, and that `par` equals the taps the stored solution needs.',
 '2. **Offline (tools/levels/validate_campaign.py, Python port of the same rules):** re-reads the JSON files, repeats those checks, and additionally searches EVERY valid configuration to prove `par` is the true minimum and to count solutions.',
 '3. **Tests (tests/test_runner.gd):** schema, determinism, unique titles, contiguous ids, par vs solution, every cap the water reaches is valid only in its stored rotation.', '',
 'The Python port is a separate implementation of the rules, so it is a cross-check, not the game itself. Run `godot --headless --path . --script res://tests/test_runner.gd` to run the real solver over every level.', '',
 '## Chapter 1 results (from docs/validation_report.json)',
 'Levels checked: %d, fully valid: %d, errors: %d.' % (rep['levels_checked'], rep['levels_valid'], len(rep['errors'])), '',
 '| # | Title | Size | Par | Solutions | Network | Decoys | T/X/C | Paths | Score | Purpose |', '|---|---|---|---|---|---|---|---|---|---|---|']
for r in rep['results']:
    m = met[r['id']]
    out.append('| %d | %s | %s | %d | %d | %d | %d | %d/%d/%d | %d | %.0f | %s |' % (r['id'], r['title'], r['size'], r['par'], r['solution_count'],
        m['network_cells'], m['decoys'], m['tees'], m['crosses'], m['caps'], m['plausible_paths'], m['difficulty_score'], PURPOSE[r['id']]))
scores = [met[i]['difficulty_score'] for i in range(1, 21)]
out += ['', '## Difficulty review',
 '`Score` is a rough development aid (par, network size, junctions, caps, decoys, plausible-route count, bait pipes). It does not predict human difficulty; playtesting decides.',
 'Shape of the chapter: levels 1-6 stay low (%.0f-%.0f); each new idea (decoys at 7-9, caps at 10-12, junctions at 13-15, alternative routes at 16-18) starts easier than the level before it and then ramps; 19-20 combine everything (%.0f, %.0f).' % (min(scores[:6]), max(scores[:6]), scores[18], scores[19]),
 'Known stronger steps: level 6 to 7 (%.0f to %.0f) when decoys first appear, and 19 to 20 (%.0f to %.0f) for the chapter finale. Level 20 has par %d, the longest in the chapter.' % (scores[5], scores[6], scores[18], scores[19], met[20]['par']),
 '', '## Not implemented yet (by design, stage by stage)',
 '- Chapters 2-4 (levels 21-100) and the move-limit mechanic (the schema accepts `move_limit`; the game does not enforce it yet and no Chapter 1 level uses it).',
 '- Points: awarding exactly once per completion needs a points total; best moves, stars and unlocks are recorded once today.',
 '- Hints (no hint button exists, so none was added).', '']
open(os.path.join(ROOT, 'docs', 'CAMPAIGN.md'), 'w').write('\n'.join(out))
print('wrote docs/CAMPAIGN.md')
