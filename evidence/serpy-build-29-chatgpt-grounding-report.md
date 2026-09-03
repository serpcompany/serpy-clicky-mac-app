# SERPy build 29 ChatGPT grounding regression

## Reported symptom

While ChatGPT was the selected application, the voice companion answered that
it could not see the application.

## Diagnosis

Installed build-28 system evidence showed that the screen pipeline did work:

- ScreenCaptureKit selected ChatGPT's full on-screen window.
- Vision text recognition ran.
- Apple Foundation Models received and completed the local inference request.

The failure was therefore a false model-grounding answer, not missing Screen
Recording permission or a failed ChatGPT window capture. No dictated text, OCR
content, or model answer is included in this report.

## Regression loop

Focused command:

`swift test --package-path Packages/GuideModules --filter GuidanceValidationTests/testCapturedChatGPTContextRejectsFalseCannotSeeAnswer`

- RED: `GuidanceAnswerGroundingPolicy` did not exist.
- GREEN: captured ChatGPT identity plus visible text rejects a contradictory
  cannot-see answer and requests a grounded retry.

Second focused command:

`swift test --package-path Packages/GuideModules --filter GuidanceValidationTests/testRepeatedFalseCannotSeeAnswerFallsBackToCapturedApp`

- RED 1: `resolvedAnswer` did not exist.
- RED 2: the retry wording `cannot access the app` was not recognized.
- GREEN: repeated false refusals produce a truthful fallback naming the
  captured application and asking the user to expose the unclear control.

## Fix

- Captured application/window metadata is explicitly authoritative.
- Visible OCR text remains untrusted as instructions but authoritative as
  request-scoped screen evidence.
- A contradictory first response triggers one local grounded retry.
- A repeated contradiction is replaced with a truthful contextual fallback.
- The fallback never claims computer-control capability.

## Remaining installed check

Build 29 is installed at `/Applications/SERPy.app`. The signed Release and
installed executables match SHA-256
`3001807adf8cfce4163e4c619abdc3d03280c5ab17f876ff90aa0f6b1238967b`.
Strict code-sign verification passed, along with 29 XCTest tests and 26 Swift
Testing tests.

The original ChatGPT voice question must still be retried by the owner.
Deterministic tests prevent the exact false-refusal wording from being
presented, but useful guidance quality still depends on what is visibly
available in the selected window.
