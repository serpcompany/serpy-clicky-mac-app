# SERPy build 27 native menu evidence

## Purpose

Build 27 replaces the fixed-width, vertically unbounded custom menu-bar
dashboard with SwiftUI's native macOS menu presentation. The previous card
stack could extend beyond the usable display and clip Settings, Quit, and other
content.

## Artifact identity

- Product: SERPy 0.1.0 (27)
- Installed path: `/Applications/SERPy.app`
- Bundle identifier: `com.serpcompany.guidecompanion.internal`
- Architecture: arm64
- Installed executable SHA-256:
  `14e10cdba2f400ab568e3ff1c56a401006262431aa4bdc4b90586647875a9265`
- Release-build executable SHA-256 matched the installed executable.
- Developer ID signature and designated requirement verification passed.

This is installed-development evidence, not a notarized DMG release report.

## Implementation evidence

- `MenuBarExtra` now uses `.menu`, not `.window`.
- The menu uses native `Section`, `Button`, `Toggle`, `Menu`, `Divider`, and
  `SettingsLink` components.
- The menu is limited to concise status and primary actions for dictation,
  voice guidance, companion visibility, recovery, Settings, and Quit.
- Long onboarding copy, manual tests, diagnostics, and permission recovery
  remain in the normal Settings window.
- The fixed width, custom backgrounds, card stack, and bottom action row were
  removed from the menu surface.

## Verification

- Full Swift suite passed: 22 XCTest tests plus 26 Swift Testing tests.
- Developer ID Release build succeeded.
- Installed app reports build 27 and launches from `/Applications/SERPy.app`.
- The installed executable matches the exact Release-build executable.

## Remaining observation

The source and installed artifact establish use of the OS-owned menu component,
but B9 remains `implemented` until the owner captures or confirms the opened
build-27 menu on the affected display. The screenshot that motivated this
change depicts the rejected pre-build-27 custom window surface.
