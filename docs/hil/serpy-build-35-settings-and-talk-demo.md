# SERPy build 35 Settings HIL — rejected

Use only the installed Developer ID build `0.1.0 (35)` whose executable
SHA-256 is
`c1ac9ac6144c90498e30b64f7269e971dd9f7b548350d9a7905c6c2f63216b67`.

The live menu-bar loop rejected this build: the Settings window was created,
but SERPy remained `frontmost=false` after the menu closed. Build 36 supersedes
it by scheduling a second activation after the menu-bar action returns.

## Menu-bar Settings regression

1. Put another application in front of SERPy.
2. Open SERPy's menu-bar menu and choose **Settings…**.
3. Confirm SERPy activates and its existing or newly created Settings window is
   raised above the previously active application.
4. Close Settings and repeat once to cover both window creation and reuse.

The menu action now uses the same Settings scene as Command-Comma, but first
activates the menu-bar-only application. The deterministic regression test
requires activation to occur before opening the Settings scene.

## Talk verification

After the Settings regression passes, run every safety, provider, voice,
multimodal, streaming, cancellation, spatial-cue, and privacy check in
`serpy-build-34-openai-talk-demo.md` against build 35. Build 35 contains only
the Settings presentation correction on top of that reviewed Talk slice.

Do not mark Talk rows passed without the installed, credentialed human
observations required by that guide. Automated work must not make a live API
request.
