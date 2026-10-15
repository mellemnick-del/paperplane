# Paper Plane: notes for Claude

Paper Plane is Nick's iPhone game. This repo is its own project. Never touch the Tick app
or its repo (mellemnick-del/Tick).

## Source of truth
- `prototype/index.html` is the web prototype Nick loves. The native app must look and feel
  exactly like it. When changing gameplay or drawing, change the prototype logic's Swift port
  faithfully and keep the numbers in sync.
- All sizes and speeds are in screen heights (H) so it plays the same on any iPhone.
  Do not change tuning numbers unless Nick asks.

## Tech rules
- SwiftUI, iOS 17+, iPhone only, portrait, status bar hidden. No third-party libraries.
- Everything is drawn in one SwiftUI `Canvas`. Game rules live in the plain Swift class
  `GameEngine`; `FrameClock` (a CADisplayLink) calls `step(to:)` once per display frame and
  then bumps a published counter so SwiftUI redraws.
- Do not go back to `TimelineView(.animation)` for the game loop. On Nick's iPhone it did not
  tick: the game only advanced when a touch changed view state (seen in a screen recording).
- Debug builds show a small red readout in the top-right corner (fps, state, touch, plane y).
  It is compiled out of release builds. Ask Nick for a screenshot of it when debugging.
- Input is `DragGesture(minimumDistance: 0)`: onChanged = finger down, onEnded = finger up.
- Xcode project uses folder sync (objectVersion 77): files added under `PaperPlane/` are
  included automatically. Do not add files to the project by hand. `Info.plist` is excluded
  from the target's resources by an exception set; keep it that way.
- Bundle ID `com.nickmellem.paperplane`, display name "Paper Plane".
  Bump `CURRENT_PROJECT_VERSION` (build) for every TestFlight upload.
- Best score is stored in UserDefaults; `PrivacyInfo.xcprivacy` declares reason CA92.1,
  no tracking, no data collected. Update it if any new required-reason API is used.
- Cloud sessions run on Linux without Xcode, so code cannot be compiled there. Say so
  plainly, keep Swift conservative, and ask Nick to build on his Mac after changes.

## Writing style
- Never use em dashes in anything written for Nick: code comments, docs, commit messages, chat.

## Working rules
<!-- Nick's "How we build apps together" rules go here. -->
