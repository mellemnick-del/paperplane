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
- SwiftUI, iOS 17+, status bar hidden. No third-party libraries.
- Orientation: Info.plist allows all; `AppDelegate` narrows it at run time. Regular iPhones are
  portrait only; screens whose short side is 600+ points (opened foldable iPhones) and iPads
  get every orientation, so the page fills the screen instead of being letterboxed.
  iPad: resizable windows too. The engine rescales the
  world when the screen size changes (`rescale`). Line widths and caption text scale by
  `k = max(1, H / 956)`, so every iPhone is unchanged and iPads get thicker strokes.
- How-to notes: the start screen is a hand-drawn diagram (the plane demos hold/let go in a
  2.4 s loop, a sample pencil pair shows the goal). A player's first 3 games
  (`GameEngine.learnerGames`, counted in UserDefaults as `paperplane.gamesPlayed`) show
  fading notes at the wings, score and first gap, and start with a wide gap lined up with
  the plane. Notes are drawn on the start screen too, so their stroke styles are warmed up.
- The spacebar works like a finger (iPad and Mac keyboards), handled in `TouchSurface`.
- Everything is drawn in one SwiftUI `Canvas`. Game rules live in the plain Swift class
  `GameEngine`; `FrameClock` (a CADisplayLink) calls `step(to:)` once per display frame and
  then bumps a published counter so SwiftUI redraws.
- Do not go back to `TimelineView(.animation)` for the game loop. On Nick's iPhone it did not
  tick: the game only advanced when a touch changed view state (seen in a screen recording).
- Input is `TouchSurface`, a UIKit view: any finger down = hold, all fingers up = let go.
  Do not go back to a SwiftUI DragGesture: it never reports touches iOS cancels, so the game
  thought the finger was still down and ignored new touches. Keep `.defersSystemGestures`,
  otherwise iOS's system gesture gate delays or drops touches near the screen edges.
- The renderer draws every stroke style invisibly on the start screen (`warmUp`), because
  iOS builds each GPU pipeline on first use and that froze play for ~0.5 s. Anything new
  drawn during play should be added there too.
- Xcode project uses folder sync (objectVersion 77): files added under `PaperPlane/` are
  included automatically. Do not add files to the project by hand. `Info.plist` is excluded
  from the target's resources by an exception set; keep it that way.
- Bundle ID `com.nickmellem.paperplane`, display name "Paper Plane".
  Bump `CURRENT_PROJECT_VERSION` (build) for every TestFlight upload.
- Best score is stored in UserDefaults; `PrivacyInfo.xcprivacy` declares reason CA92.1,
  no tracking, no data collected. Update it if any new required-reason API is used.
- App Store kit lives in `appstore/` (listing text, screenshots, header banners). The support
  and privacy pages are `docs/`, served by GitHub Pages from main /docs at
  https://mellemnick-del.github.io/paperplane/ (support email nmellemapps@gmail.com).
  Version 1.0 was submitted to App Review on 2026-10-19 with no ads and "Data Not Collected";
  adding ads later means updating the privacy label, PrivacyInfo.xcprivacy and privacy.html.
- Cloud sessions run on Linux without Xcode, so code cannot be compiled there. Say so
  plainly, keep Swift conservative, and ask Nick to build on his Mac after changes.

## Writing style
- Never use em dashes in anything written for Nick: code comments, docs, commit messages, chat.

## Working rules
<!-- Nick's "How we build apps together" rules go here. -->
