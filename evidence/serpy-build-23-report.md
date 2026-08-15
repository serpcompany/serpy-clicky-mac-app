# SERPy build 23 release evidence

## Purpose

Build 23 corrects global shortcut isolation. Build 22 rejected a mismatched
`Command-Space` key-down but consumed its `Space` key-up, which could break
Alfred, Spotlight, and other applications that need the complete key cycle.

## Artifact identity

- Product: SERPy 0.1.0 (23)
- Source commit: `90b849ef9bb3265fdd6c4d11238b242fa90dcef5`
- DMG: `dist/SERPy-0.1.0-23.dmg`
- SHA-256: `25f42f18f6d84776259a8701627825c1c1cb8091716511c2f2bde6e291bef8d2`
- Architecture: arm64
- Bundle identifier: `com.serpcompany.guidecompanion.internal`

## Deterministic regression evidence

- The new `Command-Space passes through on both key down and key up` test
  failed against the build-22 policy because the key-up was consumed.
- After the policy fix, all four global-hotkey event-delivery tests passed.
- The full Swift suite passed: 11 XCTest tests plus 26 Swift Testing tests.
- The configured `Option-Space` down/up cycle remains consumed.
- A `Command-Space` down/up cycle now passes through in full.
- Mismatched releases for the guidance key also pass through in full.

## Distribution verification

- Developer ID Release build: passed
- DMG signature and checksum validation: passed
- Apple notarization: accepted
- Stapling and staple validation: passed
- Gatekeeper assessment of DMG: accepted
- Gatekeeper assessment of mounted app: accepted
- Exact mounted app installed to `/Applications/SERPy.app`
- Installed bundle reports build 23 and launches without Xcode

## Human check still required

While installed build 23 is running, press `Command-Space` and confirm the
owner's configured launcher opens normally. Mac UI automation cannot issue a
true global shortcut, so this final application-to-application observation is
kept separate from the deterministic event-policy regression test.
