# M3 post-authentication checkpoint — 2026-09-05

## Focused automated test

- Source: `9944e06` plus documentation-only AGENTS change.
- Command: `scripts/run-golden-ui-test.sh focused GuideCompanionUITests/GoldenGuideUITests/test_GT_UF11_001_realSettingsEnforcesInMemoryTalkAuthorization evidence/issue-13-real-app-UF11-post-auth.xcresult`
- Result bundle summary: Passed, 1 test, 0 failures, 0 skips; macOS 26.5.2 arm64.
- Wrapper exit: 0. Owned build root removed; no SERPy or XCUI process remained.
- Uses deterministic fixtures and an in-memory fake credential; no real API
  key, OpenAI request, or paid-provider evidence.
- Does not resolve intermittent Xcode Cloud launch failure or count toward
  the ten-run cloud burn-in.

## Installed observation

- Artifact: `/Applications/SERPy.app`, existing build 43.
- Executable SHA-256: `b869bfdc5ecfd038cc2b7fe8c822d12b9d68c5a23f1506475a271725fe58414c`.
- After the owner authentication dialog cleared, Refresh reported Microphone,
  Speech Recognition, and Accessibility Granted.
- Quit and relaunch reported shortcut Registered, with the same grants.
- In an empty disposable TextEdit document, the existing text-insertion-only
  diagnostic left the target visibly empty. SERPy nevertheless displayed
  `Insertion test succeeded via pasteUnconfirmed` and `The insertion test
  succeeded.` The exact cross-app focus cause has not been established.
- Source seam: `GuideAppModel.beginInsertionTest()` treats every nonthrowing
  insertion result as success, including unconfirmed paste. The new
  `GuideAppModelDictationTests.insertionDiagnosticReportsEvidence` calls this
  production method with all four insertion results. Before correction it
  failed three assertions for unconfirmed paste; after using the existing
  `isConfirmed` distinction, all four cases pass. The complete bounded
  `core-tests` command exits zero, as does bounded `app-build` compilation of
  the production app and UI-test bundle. This fixes source presentation only;
  build 43 is unchanged and the cross-app delivery cause remains unresolved.
- No microphone recording was performed; microphone capture, exact insertion,
  clipboard preservation, cancellation, and recovery acceptance remain red.
- The empty, unsaved TextEdit document remains open as the next test target.

No credentials, clipboard contents, audio, or screenshots are retained here.
