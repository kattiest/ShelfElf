# ShelfElf Session Handoff — 2026-11-08

## What happened this session

### 1. Android release crash on launch — FIXED
- Symptom: release APK died instantly on open; debug worked
- Real cause: R8 minify stripped/renamed WorkManager's `WorkDatabase`
  (Room runtime reflection). Debug has minify off — that's why only release crashed
- Fix: Room/WorkManager keep rules in `android/app/proguard-rules.pro`
- Verified: release APK launches + stays alive on R5CT912NCBZ

### 2. OpenRouter AI meal planner
- Key works. Google free pool (Gemma) congested → 429s; Nvidia models fine
- Default model switched to `nvidia/nemotron-3-ultra-550b-a55b:free` (tested live)
- Free models rotate; check openrouter.ai/models?max_price=0 when one 429s
- Meal planner verified working on-device by Karlie

### 3. Secret protection — IMPORTANT
- Real OpenRouter key lives ONLY in local `lib/config/api_config.dart`
- That file is now untracked + properly gitignored (old .gitignore only had a
  COMMENT mentioning it — comments don't ignore; verify with `git check-ignore`)
- CI restores placeholder from `lib/config/api_config.ci.dart` before building
- Never `git add -f lib/config/api_config.dart`

### 4. iOS CI — GREEN (was the whole evening's saga)
- The "select Development Team" error was a LIE — Flutter prints it for ANY
  iOS build failure. Actual chain of real fixes:
  a. `IPHONEOS_DEPLOYMENT_TARGET` 13.0 → 15.0 (firebase SPM requirement)
  b. `CODE_SIGN_STYLE = Manual` + `PROVISIONING_PROFILE_SPECIFIER = ""` on ALL
     configs including Runner (June fix f10f099 only hit RunnerTests)
  c. `CODE_SIGNING_ALLOWED=NO` passed as xcodebuild ARG (env vars don't propagate)
  d. The real error all along: missing `api_config.dart` in CI (from secret fix)
     → Dart compile failed in Run Script phase. Fix = placeholder copy step.
- Workflow now: config-only flutter build → raw xcodebuild (tee full log) →
  archive → IPA packaging → upload-artifact `ShelfElf-ios`
- Distribution: sideload (Sideloadly/AltStore) — 7-day resign cycle, test device only

## Current state
- Android: APK builds, launches, meal planner works, on Karlie's phone
- iOS: CI fully green, unsigned IPA artifact (~15MB), sideload-ready
- Repo: kattiest/ShelfElf, HEAD `43526bb`
- No Play Store plans — gift project for a friend's mother, sideload only
- Ads groundwork (ad_service, banner_ad_widget, google_mobile_ads) exists but is
  pointless for sideload distribution — first cut candidate if it causes trouble

## Open threads
- flutter build crashes if `api_config.dart` missing locally too (CI placeholder
  pattern could be adopted for local builds if this bites)
- Kotlin KGP deprecation warnings (firebase plugins) — future Flutter versions
  will break the Android build; migrate or upgrade plugins eventually
- Karlie hates Apple's fee structure (ventings in commit history are personal,
  not strategy)
