# Dilated

A macOS game that trains eye speed for practical shooting (USPSA).

Dilated turns the visual skills that limit speed on a stage — target transitions, A-zone acquisition, shoot / no-shoot calls, peripheral pickup, movers, and stage reading — into short drills, and each drill into a number you can watch improve.

> **Status: early development.** Phase 0 (project skeleton) is done. The drills are not built yet. See the [roadmap](arch.md#16-roadmap-and-time-estimates).

## Drills

| Drill | Trains | Main score | Phase |
|---|---|---|---|
| **Flash Acquire** | Getting the eyes onto the A-zone of a new target | Acquire threshold (ms) | MVP |
| **Transition Ladder** | Target-to-target transitions, eyes leading | Splits, hit factor | MVP |
| **No-Shoot Discriminator** | Shoot / no-shoot decisions | Median RT, false-alarm rate, d′ | MVP |
| **Peripheral Pickup** | Seeing targets out of the corner of the eye | Pickup threshold (ms) | 2 |
| **Mover Read** | Reading swingers, movers, drop-turners | Speed at threshold (°/s) | 2 |
| **Stage Scan** | Reading and remembering a target array | Recall %, threshold (ms) | 2 |
| **Schulte Grid** | Visual search warm-up | Completion time (s) | 2 |

Sizes are set in degrees of visual angle after a one-time screen calibration, so scores compare across Macs. Timing counts display frames, not timers.

## Requirements

- macOS 14 Sonoma or later, Apple Silicon. A 120 Hz ProMotion display is preferred; 60 Hz works.
- Xcode 27 or later (Swift 6.4).
- A wired keyboard is recommended. Bluetooth adds input delay.

## Build and test

```bash
git clone https://github.com/jnaugle-nvidia/dilated.git
cd dilated

# Package tests (seconds, no app window)
for p in Packages/*/; do swift test --package-path "$p"; done

# App build + unit tests
xcodebuild -project App/Dilated.xcodeproj -scheme Dilated -destination 'platform=macOS' \
  -only-testing:DilatedTests test
```

`-only-testing:DilatedTests` skips the UI test, which takes over the screen while it runs.

**Signing:** the project is set to the author's Apple team. To build it yourself, open `App/Dilated.xcodeproj`, go to **Signing & Capabilities**, and pick your own team (or "Sign to Run Locally").

## Project layout

```text
App/                 Xcode project: SwiftUI app, unit tests, UI tests
Packages/
  DilatedCore/       Pure Swift: drill rules, staircase, scoring, visual angle
  DilatedEngine/     Frame timing, input, rendering, audio
  DilatedData/       SwiftData storage and CSV export
arch.md              Architecture and design doc
```

Start with [arch.md](arch.md). It covers the drills, the timing rules, and why the code is split this way.

## Health and privacy

- **Photosensitivity warning:** the app flashes images. Do not use it if you have a history of seizures. Stop if you get a headache or eye strain.
- Not a medical or vision-therapy product.
- No network calls, analytics, or accounts. Data stays on your Mac.

## License

[MIT](LICENSE).

Dilated is not affiliated with or endorsed by USPSA.
