# Paper Plane: App Store kit

Everything to paste into App Store Connect, in the order the pages ask for it.
Character counts were checked against Apple's limits.

## App information

| Field | Value |
| --- | --- |
| Name (30 max) | `Paper Plane: Notebook Flight` (28) |
| Subtitle (30 max) | `Hold to climb. Let go to dive.` (30) |
| Bundle ID | `com.nickmellem.paperplane` |
| SKU | `paperplane-ios-001` |
| Primary language | English (U.S.) |
| Primary category | Games, subcategory Arcade |
| Secondary category | Games, subcategory Casual |
| Content rights | Does not contain third-party content requiring rights (both fonts are open licensed and bundled with their licenses) |
| Price | Free |
| Availability | All countries |

The name under the icon on the phone stays "Paper Plane". The store name needs to be
unique, and plain "Paper Plane" is almost certainly taken. Backups if this one is taken too:
`Paper Plane: Pencil Run`, `Paper Plane Doodle Flight`.

## Version 1.0

**Promotional text** (170 max, can be changed any time without a review):

```
Fold up, take off, and thread the pencils. One finger, one notebook page, and a best score that won't beat itself. How far can you fly?
```

**Description** (4000 max):

```
Hold to climb. Let go to dive. That's the whole game, and it's harder than it sounds.

Your paper plane is loose on a sheet of notebook paper, and the pencils are closing in. Thread the gaps between them, one pencil pair at a time. Every pair you clear is a point. The page speeds up and the gaps get tighter the longer you last.

CLIP A PENCIL, CRUMPLE A WING
Brush a pencil or scrape the edge of the page and a wing crumples. Your plane gets creased, a little wobbly, and a little harder to lift. You get a moment to recover, then it's back to work. Three crumples and you're done.

THE DETAILS
• One-finger controls: hold anywhere to climb, let go to dive
• A hand-drawn notebook world: ruled lines, margin, doodles and coffee rings
• Wings that crease and bend with every hit
• Paper crumple sounds and haptics you can feel
• Your best score saved on your phone

PICK UP AND PLAY
No account, no setup, no tutorial to sit through. It works offline, anywhere: on the couch, in line, or in the back of class.

How many pencils can you clear?
```

**Keywords** (100 max, comma separated, no spaces after commas; words already in the name
are indexed automatically, so they are left out):

```
airplane,glider,arcade,one tap,casual,pencil,doodle,fly,offline,endless,sketch,origami,simple,tap
```

**Support URL:** `https://mellemnick-del.github.io/paperplane/support.html` (see Hosting below)

**Marketing URL:** optional, leave blank

**Copyright:** `2026 Nick Mellem`

**What's New:** not shown for a first release.

## Screenshots

Upload the four files in `appstore/screenshots/`, in order, to the **6.9" Display** slot
(1320 x 2868). Apple scales them down for smaller iPhones, so this one size is enough.

1. `1-hold-to-climb.png`
2. `2-crumple-a-wing.png`
3. `3-beat-your-best.png`
4. `4-endless-pencils.png`

## App Privacy

- Privacy Policy URL: `https://mellemnick-del.github.io/paperplane/privacy.html`
- "Do you or your third-party partners collect data from this app?" **No, we do not collect data.**
- Result: the listing shows **Data Not Collected**.

The best score is stored only on the device (UserDefaults), and `PrivacyInfo.xcprivacy`
already declares that, so nothing else is needed.

If a later version adds ads (for example Google AdMob), this answer, the privacy manifest
and `docs/privacy.html` must all be updated in that same release, because ad networks
collect device data and usually need Apple's tracking permission prompt.

## Age rating

Answer **None** or **No** to every question (no violence, no gambling, no web access,
no user-generated content, no messaging). Result: **4+**.

## Export compliance

Already answered in the app (`ITSAppUsesNonExemptEncryption = NO`), so App Store Connect
will not ask.

## App Review notes

```
Paper Plane is a single-screen arcade game. Hold anywhere on the screen to climb, release to dive, and fly through the gaps between pencils. No account or login is needed, and the app collects no data.
```

Sign-in required: No. Contact info: your name, phone and email (only Apple sees these).

## Hosting the privacy and support pages

Apple needs a public web address for both pages. They are in `docs/` in this repo.

Option A, GitHub Pages (free if the repo is public):
1. On GitHub, open the paperplane repo and click **Settings > Pages**.
2. Under **Build and deployment**, set Source to **Deploy from a branch**, branch **main**,
   folder **/docs**, and click **Save**.
3. After a minute or two the pages are live at the URLs above.

Option B, if you want to keep the repo private: tell Claude, and it can publish the two
pages somewhere else and update the URLs here.

Before publishing, replace `[your support email]` in `docs/support.html` and
`docs/privacy.html` with the address you want players to use.
