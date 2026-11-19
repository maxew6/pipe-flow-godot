# Pipe Flow v0.5.0 — build and verification report

## Summary

This repository contains the corrected v0.5.0 Godot project, its Android export preset, automated verification tools, and real-scene screenshot evidence. A signed ARM64 debug APK is attached to the [v0.5.0 GitHub Release](https://github.com/maxew6/pipe-flow-godot/releases/tag/v0.5.0).

## Source fixes

- Added the missing pure-core `LevelLoader.difficulty_of(level)` accessor used by level selection and campaign tests.
- Made `UiKit`'s click feedback lookup optional so its `Feedback` autoload is not required by SceneTree tests; regular game clicks still play feedback when the autoload exists.
- Clamped the tank water-wave amplitude at low water levels to prevent the surface polygon from intersecting the rounded base and failing triangulation.
- Changed test-only `BoardView` references to dynamic `Variant` where tests intentionally inspect private runtime state rejected by static GDScript typing.
- Added Android ETC2/ASTC import support and a portrait ARM64 debug export preset. Private keystore files are not included.

Core puzzle logic remains independent of nodes and autoloads: no such references were added under `scripts/core/`.

## Verification evidence

- Godot **4.7.2.stable.official.ed1daf0bf** project import: no parser/resource errors.
- Godot test suite: **506 passed, 0 failed**.
- `python3 tools/verify/solver_mirror.py`: passed. All **20** stored level solutions are valid and sealed; negative checks cover reachable leaks, misoriented caps, open ends facing empty cells or the board edge, and cycles.
- Real-scene proof harness: 11 screenshots captured at **1080×1920** and another 11 at **1080×2400**. It exercises menu, settings, level select, gameplay, pause, water-flow timeline, completion, and a reachable-tap route rejected for a leak.
- APK signature and Android manifest verified with Android SDK tools. The included log files are under [`verification/`](verification/).
- Full screenshot list and descriptions: [`screenshots/SCREENSHOT_INDEX.md`](screenshots/SCREENSHOT_INDEX.md).

## Android build

| Field | Value |
|---|---|
| App / package | Pipe Flow / `com.pipeflow.game` |
| Version | 0.5.0 (code 50) |
| Orientation | Portrait |
| ABI | ARM64 (`arm64-v8a`) |
| Min / target SDK | 24 / 36 |
| Permission | VIBRATE |
| Signing | Android Debug certificate; APK Signature v2 and v3 verified |

Toolchain: Godot 4.7.2; OpenJDK 21.0.12; Android SDK Platform 35; Build Tools 35.0.1; Platform Tools 37.0.1; NDK 28.1.13356709; CMake 3.22.1.

The debug APK can be installed on a compatible ARM64 Android phone after allowing installation from the chosen file manager/browser. It is a debug/sideload artifact, not a Play Store release. No Android device or emulator was available, so physical-device installation, runtime behavior, Back-button behavior and device-specific safe-area handling remain unverified.

## Reproduction

Open the project root in Godot 4.7.2, then run:

```bash
godot --headless --path . --script res://tests/test_runner.gd
python3 tools/verify/solver_mirror.py
```

For Android export, install matching Godot export templates and Android SDK tools, configure a debug keystore in the Android preset, then run:

```bash
godot --headless --path . --export-debug Android build/pipeflow-v0.5.0-debug.apk
```

The keystore itself is intentionally excluded; configure your own path and alias for local exports.
