# SERPy build 25 AI Guide evidence

## Purpose

Build 25 replaces the single one-shot screen recommendation with a normal,
non-floating AI Guide conversation. The user can ask a question, read the local
answer, and ask follow-up questions that include recent conversation and fresh
computer context.

## Artifact identity

- Product: SERPy 0.1.0 (25)
- Installed path: `/Applications/SERPy.app`
- Bundle identifier: `com.serpcompany.guidecompanion.internal`
- Architecture: arm64
- Signing: Developer ID Application; designated requirement verified

This is installed-development evidence, not a notarized release report. Source
commit identity is added by the commit containing this report.

## Deterministic evidence

- Full Swift suite passed: 18 XCTest tests plus 26 Swift Testing tests.
- Four conversation state tests cover multi-turn flow, empty and overlapping
  turns, visible failure recovery, and new-conversation reset.
- A prompt-budget test bounds OCR context before it reaches the local model.
- Two output-sanitizer tests remove echoed internal prompt labels and speaker
  prefixes before presentation.
- The Developer ID Release build succeeded and its signature passed strict
  verification.

## Installed observation

- The installed build reported Xcode build 25.
- AI Guide opened as a standard titled, closable, resizable window at normal
  window level.
- The empty state, question field, Send control, source-context label, and New
  Conversation control were visible through macOS Accessibility.
- A first question captured a non-product window and returned an on-device
  answer.
- A follow-up question returned an answer that retained the meaning of the
  prior turn.
- A deliberately text-heavy context initially exceeded the local model window;
  after adding the deterministic prompt budget, the same path completed.
- A model response that initially echoed internal prompt sections motivated the
  tested presentation sanitizer; the final two-turn observation displayed only
  the guide answers.

The observation used harmless questions. Dictated text, raw screen text, and
screenshots are intentionally omitted from this report.

## Evidence boundary

The Xcode UI test runner timed out while macOS was enabling automation mode,
before the UI tests executed. Direct installed Accessibility inspection proves
the window and two-turn interaction above, but the automated UI suite is not
reported as passing. Broader scenario quality and target-window selection
remain human-evaluation concerns rather than generalized claims.
