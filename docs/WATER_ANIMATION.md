# Water animation (v0.4.0)

## Architecture
| Layer | File | Job |
|---|---|---|
| Rules | `scripts/core/flow_solver.gd` | Decides IF and WHERE water flows (unchanged). `first_problem()` names the one spot to highlight on failure. |
| Timeline | `scripts/core/flow_plan.gd` | Turns the validated route into times: when each pipe is entered/centred/exited, tank level, valve, stream, pool. Pure maths, unit-tested. |
| Rendering | `water_art.gd` (per tile), `fixture_art.gd` (tank + tap), `water_style.gd` (look), `board_view.gd` (conductor) | Replay the plan. They never decide connections. |

## Sequence (valid route)
1. Tank full. Press Start Water: route validated first.
2. t=0: water leaves the tank, tank level starts to fall smoothly (smoothstep) toward "nearly empty".
3. Water crosses the outlet, enters the first pipe, then each pipe in turn: straight arms, a smooth curve through elbows, branches from the centre for tees/crosses/caps. A pipe is entered exactly when the previous one is full.
4. Highlights slide along the flow direction; a few bubbles drift; the metal stays visible around the narrower water column.
5. Water reaches the tap inlet; the T-handle turns 90 degrees; the stream fades in with droplets, ripples and a pool.
6. Stream runs until the tank is nearly empty, then tapers off; the completion screen follows.

## Invalid route
"Invalid" means the tap is not reached OR any reachable open end leaks (see SEALING_RULE.md). Nothing flows, the tank is NOT drained (it only rocks slightly), the first problem (tank side closed / last pipe not facing the tap / first dead end met by the water) gets a pulsing red marker and a shake, then the failure message shows. No reward, no victory.

## Safety
- Repeated Start Water presses: ignored while running (game state + `BoardView.play_flow` guard).
- Reset: `stop_flow()` + `clear_water()` cancel everything and restore the full tank, closed tap, no bubbles/stream.
- Leaving the scene: animations are `_process` / node-bound tweens, so they stop when the nodes are freed. Pausing freezes them.
- Cycles: the plan only follows the solver's search tree, so loops cannot repeat or hang.

## Manual test steps (not yet run on a device)
1. Level 1, solve it, Start Water: tank starts full, level falls steadily; water enters the first pipe after ~0.4 s; water crosses elbows in a curve (not a corner); handle turns; stream + splash; tank nearly empty; completion panel.
2. Start Water on the unsolved level: no water, tank stays full, red pulsing marker on the first problem, message appears. Rotate a pipe and try again.
3. Press Start Water repeatedly while it runs: only one animation.
4. Press Reset mid-flow: tank full again, no water/bubbles/stream left. Start again: works.
5. Pause mid-flow: everything freezes; Resume continues; Home mid-flow: no errors.
6. Level 4 (tee + cap) and Level 5 (cross + caps): branches fill from the centre outward; capped ends stay closed.
7. Check 1080x1920 and 1080x2400: bottom Reset/Start buttons have a clean, smooth background (no dark arc).
