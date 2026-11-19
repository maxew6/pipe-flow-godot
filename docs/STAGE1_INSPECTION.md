# Stage 1 - Project inspection (v0.2.0 -> v0.3.0)

Method: read every file in the project. Nothing below was observed by running Godot
(no Godot runtime was available), so "working" means "implemented and logically consistent
with the core tests", not "seen on a device".

## Scenes (all screens are built in code; each .tscn is just a root Control + script)
| Scene | Script | Role |
|---|---|---|
| scenes/main_menu.tscn | scripts/screens/main_menu.gd | Start scene (project.godot `run/main_scene`) |
| scenes/level_select.tscn | scripts/screens/level_select.gd | Difficulty sections + level grid |
| scenes/game.tscn | scripts/game/game.gd | Gameplay, HUD, pause, completion panel |

Autoloads: `SaveManager` (save file), `Feedback` (tone SFX + vibration), `Nav` (fade scene changes, picked level).

## Navigation map
- Menu: Play/Continue -> Game(resume level) - Levels -> Level select - Settings -> overlay
- Level select: back / Esc / Android Back -> Menu; level tile -> Game(level)
- Game: Pause -> Resume / Restart / Settings overlay / Levels / Home; Back/Esc opens pause
- Level complete: Next (or Level Select after the last level) / Replay / Home

## Working features carried forward (unchanged by this redesign)
Pipe rotation + deterministic solver (`scripts/core/`), 5 validated Easy levels, move counter + par + stars,
Start/Reset/Retry flow, save/unlock logic, SFX/vibration toggles, pause tree-freeze, safe-area margins.
Core logic tests: `tests/test_runner.gd` (written, not yet run in Godot).

## Assets before v0.3
There was no `assets/` folder. Everything was drawn in code:
flat polygon mountains + circle clouds (ScenicBackground), flat rounded-rectangle buttons/panels,
polygon stars, vector icons, default engine font, outlined-text logo, rectangular tank/tap, flat pipes.

## What needed replacing, and status after this release
| Item | Status |
|---|---|
| Menu background | DONE - layered illustrated scene (assets/menu) replaces flat polygons |
| Logo | DONE - assets/ui/logo.png (Erica One, layered outline/gloss) |
| Buttons (green/blue/wood) | DONE - textured 9-slice, one component (`GameButton`) |
| Panels (wood sign, parchment) | DONE - textured 9-slice |
| Icons, stars, padlock | DONE - assets/ui/icon_*.png, star_*.png |
| Typography | DONE - Erica One (display) + Outfit Bold (UI), both SIL OFL, bundled |
| Level select | PARTIAL - uses the new backdrop/buttons; category planks, 20 levels per group still to do (Stage 4) |
| Pipe tiles, board frame, tank, tap | TODO (Stage 5) |
| Water flow, tank draining, tap stream | TODO (Stage 6 - next) |
| Level-complete panel + rewards | TODO (Stage 7) |
