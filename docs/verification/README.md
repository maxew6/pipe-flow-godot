# Verification evidence

These are the final build artifacts' logs, retained to make the checks easy to audit:

- `godot-import.log` — Godot editor/resource import before export.
- `godot-tests.log` — full automated GDScript test-runner output.
- `solver-mirror.log` — independent Python checks for the sealed-network rule and all shipped level solutions.
- `real-scene-1080x1920.log` and `real-scene-1080x2400.log` — real-game capture harness output, including the reachable-tap leak rejection.
- `android-export.log` — Android debug export output.
- `toolchain-versions.txt` — engine and Android tool versions used for the build.

The proof captures themselves are under [`../screenshots/`](../screenshots/).
