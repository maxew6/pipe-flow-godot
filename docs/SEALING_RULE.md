# Sealed-network rule (v0.4.2)

## The bug
The solver recorded every reachable open end that had no partner (`dead_ends`) but still reported success whenever the
tap was reachable, and the animation, win logic and level validator only checked `reached_sink`. So a route that reached
the tap while a branch leaked was accepted. Screenshot case: Level 4, the tee at (1,0) pointing south into the BACK of the
cap at (1,1) (cap rotated to open south). The tap was reachable, so water flowed.

## Which design the game uses
Dedicated END-CAP pieces that the player rotates (piece type `cap`, token `C`, one opening). Levels 4 and 5 are built with
them and every stored solution has zero leaks. Nothing is sealed automatically, so the rule below is explicit.

## The rule
Connections are explicit N/E/S/W openings. Two neighbours connect only if BOTH have an opening facing each other.
Starting at the tank, the solver visits the connected network (breadth-first, visited set, so cycles terminate).
Every open side of every reachable pipe must be one of:
1. the tank connection (source side of the first pipe),
2. the tap connection (sink side of the last pipe),
3. a reciprocal connection to a neighbouring pipe (a cap seals an end only when ITS opening faces that pipe).

Any other reachable open side is a **leak**: it faces an empty cell, the board edge, a closed side of a pipe, or the back
of a mis-turned cap. A route is **valid** only when the tap is reached AND there is no leak anywhere in the reachable
network, including side branches. Unreachable decoy pipes never matter.

`FlowResult.valid` is the single win condition. `reached_sink` only means "the tap is reachable".

| Result | failure | Meaning |
|---|---|---|
| valid | "" | tap reached, nothing leaks |
| leak | `leak` | tap reached but at least one reachable open end |
| sink_closed | `sink_closed` | water reached the last pipe, it does not face the tap |
| source_closed | `source_closed` | first pipe does not face the tank |
| no_route | `no_route` | the tap cannot be reached |

## Consequences everywhere
- `FlowPlan.build` returns an empty plan unless `result.valid`: no animation, the tank cannot drain, the tap cannot open.
- `BoardView.play_flow` routes invalid results to the "blocked" feedback (first leak marked in red + shake, tank only rocks).
- `game.gd` records progress only from a successful `flow_finished(true)` (state machine allows it once per run).
- `LevelLoader` accepts a level only if its stored solution is valid (tap reached, sealed) and its start layout is not.
- `first_problem()` picks what to highlight: tank side closed, then last pipe not facing the tap, then the first leak the water meets.

## Tests (tests/test_runner.gd; independent mirror: tools/verify/solver_mirror.py)
| # | Case | Test |
|---|---|---|
| 1 | reciprocal openings | rule 1 |
| 2 | mismatched openings | rule 2 |
| 3 | reachable dead end | rule 3 |
| 4 | open end facing an empty cell | rule 4 |
| 5 | open end facing outside the board | rule 5 |
| 6 | correctly capped end | rule 6 |
| 7 | cap oriented wrong (all 3 wrong rotations) | rule 7 |
| 8 | valid route, no leaks (all level solutions) | rule 8 |
| 9 | tap reached + leaking branch | rule 9 |
| 10 | cycles (sealed and leaking) | rule 10 |
| 11 | every rotation | rotation table + rule 11 |
| 12 | reset during an active animation | view tests |
| 13 | success reported exactly once | view + records tests |
| 14 | invalid route never succeeds / never drains | view tests |
| - | the exact screenshot state | screenshot regression |
| - | each cap valid only in its stored rotation, all levels | caps in levels |

Note: a points total is not implemented yet. "Awarded exactly once" is tested at the level that exists today: the success
signal fires once, and `SaveData.record_completion` only counts the first completion.
