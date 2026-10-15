# Paper Plane

A hold-to-fly iPhone game. Hold anywhere to climb, let go to dive, and fly through
the gaps between pencils on a notebook page. Clip a pencil and a wing crumples.
Three strikes and you're out.

- `prototype/index.html`: the web prototype. It is the source of truth for look and feel.
- `PaperPlane/`: the native SwiftUI app (iOS 17+, iPhone, portrait, no third-party libraries).
- `PaperPlane.xcodeproj`: open this in Xcode. The app folder is synced, so new files are picked up automatically.

## Code map

| File | What it does |
| --- | --- |
| `GameEngine.swift` | All game rules, ported from the prototype's `update()`. `step(to:size:)` runs once per frame. |
| `GameRenderer.swift` | Draws a frame into the SwiftUI `Canvas`, ported from the prototype's drawing functions. Also the color palette. |
| `ContentView.swift` | `TimelineView(.animation)` + `Canvas`, the hold gesture, and the handwritten captions. |
| `SoundFX.swift` | Crumple and chirp sounds, generated in code at launch (no audio files). |
| `Haptics.swift` | Light tap per point, heavy thump per crumple. |

## Fonts

Permanent Marker (Apache License 2.0) and Patrick Hand (SIL Open Font License 1.1),
bundled in `PaperPlane/Fonts` with their license files and registered in `Info.plist`.
