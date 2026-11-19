# Pipe Flow v0.5.0 — Android debug build

This release publishes the v0.5.0 portrait puzzle game for compatible ARM64 Android devices.

## What is included

- 20 campaign levels and the sealed-network validation rule: reaching the tap is not enough if any reachable pipe end leaks.
- Animated water flow, leak markers, progress scoring, pause/settings, and the portrait-friendly menu/game UI.
- The project source, build report, 22 real-scene screenshots at 1080×1920 and 1080×2400, and verification logs are available in this repository.

## Android package

- Package: `com.pipeflow.game`
- Version: `0.5.0` (code 50)
- ABI: ARM64 (`arm64-v8a`)
- Min SDK 24; target SDK 36; portrait; VIBRATE permission.
- Signed with an Android debug certificate for sideload/testing. This is not a Play Store release.

## Verification

- Godot suite: 506 passed, 0 failed.
- Sealed-network solver mirror: all 20 bundled solutions valid and leak-free, with negative leak/cap/cycle cases covered.
- APK signature and manifest verified. A physical Android device or emulator was not available, so install/runtime behavior on hardware is not claimed.
