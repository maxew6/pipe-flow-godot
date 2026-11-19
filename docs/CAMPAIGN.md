# Campaign (100 levels, built in stages)

| Chapter | Difficulty | Levels | Theme | Status |
|---|---|---|---|---|
| 1 | Easy | 1-20 | Learn to Read the Pipes | **built and validated (20/20)** |
| 2 | Medium | 21-45 | Think Before You Turn | not built yet |
| 3 | Hard | 46-75 | Plan the Whole Network | not built yet |
| 4 | Extreme | 76-100 | Master the System | not built yet |

The game only shows chapters whose levels exist; nothing is advertised that is not in the build.

## Level data (data/levels/chapter_N.json)
Each level: `id`, `chapter`, `difficulty`, `title`, `hint` (optional message), `cols`, `rows`, `source`/`sink` (tank on the W side of column 0, tap on the E side of the last column), `grid` (starting pieces and rotations), `solution` (a known valid state), `par` (the 3-star target), `expected` ("valid"), optional `move_limit`, plus `solution_count`, `tags`, `seed` (how the start was generated; levels are fixed data, so they are identical every time).
Tokens: `.` empty, `I` straight, `L` elbow, `T` tee, `X` cross, `C` cap, followed by a rotation digit 0-3 (clockwise quarter turns).

## How every level is checked
1. **At load time, in the game (real GDScript solver):** `LevelLoader.validate_level` checks the schema, chapter/id range, piece types, that the stored solution is VALID (tap reached, every reachable open end sealed), that the start layout is NOT already valid, and that `par` equals the taps the stored solution needs.
2. **Offline (tools/levels/validate_campaign.py, Python port of the same rules):** re-reads the JSON files, repeats those checks, and additionally searches EVERY valid configuration to prove `par` is the true minimum and to count solutions.
3. **Tests (tests/test_runner.gd):** schema, determinism, unique titles, contiguous ids, par vs solution, every cap the water reaches is valid only in its stored rotation.

The Python port is a separate implementation of the rules, so it is a cross-check, not the game itself. Run `godot --headless --path . --script res://tests/test_runner.gd` to run the real solver over every level.

## Chapter 1 results (from docs/validation_report.json)
Levels checked: 20, fully valid: 20, errors: 0.

| # | Title | Size | Par | Solutions | Network | Decoys | T/X/C | Paths | Score | Purpose |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | The First Turn | 3x2 | 4 | 1 | 4 | 0 | 0/0/0 | 1 | 6 | Tap to turn; two elbows, two straights. |
| 2 | Down the Pipe | 3x3 | 6 | 1 | 5 | 0 | 0/0/0 | 1 | 7 | Straight pipes carry water in a line; elbows turn it. |
| 3 | The Staircase | 4x3 | 8 | 1 | 6 | 0 | 0/0/0 | 1 | 8 | Chain of turns, follow the route. |
| 4 | Switchback | 4x4 | 9 | 1 | 9 | 0 | 0/0/0 | 4 | 13 | A long snaking route: plan from the tank. |
| 5 | Planning Ahead | 5x3 | 8 | 1 | 7 | 0 | 0/0/0 | 1 | 9 | Work backwards from where the water must end. |
| 6 | The Detour | 5x4 | 10 | 1 | 8 | 0 | 0/0/0 | 1 | 10 | Short breather after the first long routes. |
| 7 | Look-Alikes | 4x4 | 10 | 1 | 7 | 5 | 0/0/0 | 14 | 22 | First decoys; a bait pipe pulls the wrong way. |
| 8 | The False Shortcut | 5x3 | 11 | 1 | 7 | 7 | 0/0/0 | 20 | 25 | A finished-looking line that goes nowhere. |
| 9 | Mixed Signals | 5x4 | 12 | 1 | 8 | 9 | 0/0/0 | 40 | 28 | Decoys + bait beside a corner. |
| 10 | Seal the Leak | 4x3 | 7 | 1 | 5 | 0 | 1/0/1 | 1 | 11 | First cap: a tee has a spare opening to seal. |
| 11 | Cap Orientation | 4x4 | 10 | 1 | 7 | 2 | 2/0/2 | 4 | 24 | Two tees, two caps: cap orientation matters. |
| 12 | Spare Opening | 4x3 | 8 | 1 | 6 | 4 | 1/0/1 | 10 | 19 | A tee on a bend; decoy caps do not belong to it. |
| 13 | Junction Trouble | 4x3 | 9 | 1 | 6 | 3 | 1/0/1 | 4 | 20 | A branch (spur of two) that must end in a cap. |
| 14 | Crossroads | 5x3 | 8 | 1 | 7 | 5 | 0/1/2 | 4 | 25 | The cross never turns; seal its two unused sides. |
| 15 | Two Branches | 5x4 | 12 | 1 | 12 | 4 | 2/0/2 | 10 | 29 | Two junctions, two spurs. |
| 16 | Two Ways Home | 3x3 | 6 | 2 | 5 | 3 | 0/0/0 | 2 | 9 | Two valid routes; fewer turns wins par. |
| 17 | The Tempting Loop | 4x3 | 7 | 2 | 6 | 6 | 0/0/0 | 29 | 20 | Two routes, decoys; the nearly-done loop may cost more. |
| 18 | Fork in the Pipes | 4x4 | 5 | 2 | 7 | 8 | 0/0/0 | 25 | 18 | Several routes; choose the cheapest. |
| 19 | Reading the Pipes | 5x4 | 9 | 1 | 10 | 6 | 1/0/1 | 20 | 26 | Tee + cap + bait: choose which side of the tee to open. |
| 20 | Everything Connects | 5x5 | 19 | 1 | 13 | 7 | 2/1/4 | 124 | 45 | Finale: two tees, a cross, four caps. |

## Difficulty review
`Score` is a rough development aid (par, network size, junctions, caps, decoys, plausible-route count, bait pipes). It does not predict human difficulty; playtesting decides.
Shape of the chapter: levels 1-6 stay low (6-13); each new idea (decoys at 7-9, caps at 10-12, junctions at 13-15, alternative routes at 16-18) starts easier than the level before it and then ramps; 19-20 combine everything (26, 45).
Known stronger steps: level 6 to 7 (10 to 22) when decoys first appear, and 19 to 20 (26 to 45) for the chapter finale. Level 20 has par 19, the longest in the chapter.

## Not implemented yet (by design, stage by stage)
- Chapters 2-4 (levels 21-100) and the move-limit mechanic (the schema accepts `move_limit`; the game does not enforce it yet and no Chapter 1 level uses it).
- Points: awarding exactly once per completion needs a points total; best moves, stars and unlocks are recorded once today.
- Hints (no hint button exists, so none was added).
