# Version 1.1 setup: ads, Remove Ads, Game Center

The code is on the `release/1.1` branch. Version 1.1, build 2.

AdMob IDs in the code:
- App ID `ca-app-pub-5409507532746127~9875630132` (Info.plist)
- Rewarded "Smooth a crease" `ca-app-pub-5409507532746127/6115955318`
- Interstitial "Between rounds" `ca-app-pub-5409507532746127/3489791972`

Only App Store downloads use the real ad units. Builds run from Xcode or installed through
TestFlight automatically use Google's test ads, so testing never touches the real account.

## 1. AdMob (Nick) - done except the content rating and payments
1. admob.google.com > Apps > Add app > iOS > not listed yet > name "Paper Plane".
2. Copy the **App ID** (`ca-app-pub-...~...`).
3. In that app: Ad units > Add ad unit > **Rewarded**, name "Smooth a crease". Copy its ID.
4. Add ad unit > **Interstitial**, name "Between rounds". Copy its ID.
5. Blocking controls > Ad content rating > **G** (done). Keeps ads right for the 4+ rating.
   Google estimates G earns noticeably less per ad than higher ratings. Revisit after a month
   of real numbers: PG is the middle step (may mean a 9+ age rating), T would need 13+.
6. Send the three IDs to Claude, who swaps them in:
   - `PaperPlane/Info.plist` > `GADApplicationIdentifier`
   - `PaperPlane/Monetization/AdsManager.swift` > `Unit.interstitial`, `Unit.rewarded`
7. Payments: add payment and tax info in AdMob so earnings can be paid out.

## 2. App Store Connect (Nick)
**Agreements (once):** Business > accept the Paid Apps Agreement, add banking and tax info.
Also apply for the App Store Small Business Program (15% fee instead of 30%).

**Remove Ads purchase:** your app > Monetization > In-App Purchases > +
- Type: **Non-Consumable**
- Reference name: Remove Ads
- Product ID: `com.nickmellem.paperplane.removeads` (must match exactly)
- Price: $2.99
- Display name: Remove Ads. Description: Turn off ads between rounds, and smooth a crease for free.
- Review screenshot: a screenshot of the game over screen showing the "Remove ads" button.

**Game Center leaderboard:** your app > Game Center (enable it) > Leaderboards > +
- Type: Classic. Reference name: Best score
- Leaderboard ID: `paperplane.best` (must match exactly)
- Score format: Integer. Submission: Best score. Sort: High to low
- Localization English: display name "Most pencils cleared", score format suffix " pencils"

**On the 1.1 version page:**
- Add the Remove Ads purchase and the leaderboard to the version (In-App Purchases and Game
  Center sections).
- What's New:
  ```
  Smooth a crease: after your third crumple, watch a short video to keep flying.
  Game Center leaderboard: see how you stack up.
  New Remove Ads option.
  ```

**App Privacy (update before submitting 1.1):** Data collection > **Yes**. For Google AdMob,
declare (double check against Google's "Prepare for Apple's App Store data disclosure
requirements" page for AdMob):
- Location > Coarse Location: Third-Party Advertising, Analytics. Not linked to the user.
- Identifiers > Device ID: Third-Party Advertising, Analytics. Used for tracking.
- Usage Data > Product Interaction and Advertising Data: Third-Party Advertising, Analytics.
- Diagnostics > Crash Data, Performance Data, Other Diagnostic Data: Analytics.

**Age rating:** answer **Yes** to the advertising question. Everything else stays the same.

## 3. Xcode (Nick)
1. Source Control navigator (Cmd+2) > Branches > Remote > origin > `release/1.1` >
   right-click > Checkout. Xcode downloads the Google packages (first time takes a minute).
2. Build and run on your iPhone. Ads show Google's test ads (labeled "Test Ad").
3. Purchases can be tested from a TestFlight build with a Sandbox account
   (Settings > Developer > Sandbox Apple Account on the phone).

## 4. Later: app-ads.txt
Ad networks check `app-ads.txt` on the developer website listed on the App Store page. It
needs a site at a domain root (for example a GitHub Pages user site
`mellemnick-del.github.io` or your own domain). Claude can set this up once the AdMob account
ID is known.
