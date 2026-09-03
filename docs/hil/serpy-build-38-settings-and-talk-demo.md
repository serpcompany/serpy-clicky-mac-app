# SERPy build 38 Settings and OpenAI Talk HIL

Use only the installed Developer ID build `0.1.0 (38)` whose executable
SHA-256 is
`dccc9aa8b739abb2d755e21ae62df398e21b24c1776224ef9c04107c32829a74`.

## Menu-bar Settings regression

1. Put another application in front of SERPy.
2. Open SERPy's menu-bar menu and choose **Settings…**.
3. Confirm SERPy activates and its Settings window is raised above the prior
   application.
4. Close Settings and repeat once to cover reuse of SwiftUI's retained Settings
   scene.

Automated installed observations on this exact artifact:

- First open: `count=1; frontmost=true; windows=Setup`
- Close and reopen: `count=1; frontmost=true; windows=Setup`

SERPy enters regular activation mode at the start of each Settings menu action
and restores menu-bar/accessory mode when the Settings view disappears. This
keeps Settings foreground-capable without permanently turning SERPy into a Dock
application.

## Talk verification

After the Settings regression passes, run every safety, provider, voice,
multimodal, streaming, cancellation, spatial-cue, and privacy check in
`serpy-build-34-openai-talk-demo.md` against build 38. Build 38 changes only
Settings presentation on top of that reviewed Talk slice.

Do not mark Talk rows passed without the installed, credentialed human
observations required by that guide. Automated work must not make a live API
request.
