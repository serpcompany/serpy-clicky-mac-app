# SERPy build 36 Settings HIL — rejected

Use only the installed Developer ID build `0.1.0 (36)` whose executable
SHA-256 is
`1653361e62a38bdd1020956818f5b3da0fc3d1106ef66fa25e7fddbfb0a9e29f`.

The live probe still reported `count=1; frontmost=false`. Scheduling another
activation was insufficient because the app's `LSUIElement` launch identity
kept it in accessory mode. Build 37 supersedes it by entering regular
activation policy only while Settings is visible and restoring accessory mode
when Settings closes.

Build 37 fixed first creation but failed the close-and-reopen probe because the
retained SwiftUI Settings scene did not run `onAppear` again. Build 38 also
enters regular activation mode at the start of every menu Settings action.

## Menu-bar Settings regression

1. Put another application in front of SERPy.
2. Open SERPy's menu-bar menu and choose **Settings…**.
3. Confirm SERPy activates and its existing or newly created Settings window is
   raised above the previously active application.
4. Close Settings and repeat once to cover both window creation and reuse.

The menu action activates immediately so the Settings scene can open, then
reactivates on the next main-loop turn after the status menu closes. The live
acceptance probe must report both `count=1` and `frontmost=true`.

## Talk verification

After the Settings regression passes, run every safety, provider, voice,
multimodal, streaming, cancellation, spatial-cue, and privacy check in
`serpy-build-34-openai-talk-demo.md` against build 36. Build 36 changes only
Settings presentation on top of that reviewed Talk slice.

Do not mark Talk rows passed without the installed, credentialed human
observations required by that guide. Automated work must not make a live API
request.
