# SERPy build 22 release evidence

## Artifact identity

- Product: SERPy 0.1.0 (22)
- Git commit: `a68b9c165416bd3b01d703e56469ba989177bc6e`
- DMG: `dist/SERPy-0.1.0-22.dmg`
- SHA-256: `93f45e8a66a9e6d2ffc70584950a7383c48c267391d97e442c05bf3b85f27901`
- Architecture: arm64
- Bundle identifier: `com.serpcompany.guidecompanion.internal`
- macOS: 26.5.2 (25F84)
- Xcode: 26.0 (17A324)

## Distribution verification

- Developer ID signature verification: passed
- Apple notarization: accepted
- Stapling and staple validation: passed
- Gatekeeper assessment of the DMG: accepted as Notarized Developer ID
- Gatekeeper assessment of the mounted app: accepted as Notarized Developer ID
- DMG checksum verification: passed
- Mounted DMG was copied to `/Applications/SERPy.app`
- Installed bundle reports build 22 and launches without Xcode

## Functional verification

- Swift package tests: passed, including toggle start/finish policy, Escape
  cancellation, configured-chord event consumption, shortcut persistence,
  history migration, clipboard ownership, and text insertion behavior
- Xcode Debug build: passed
- Installed shortcut registration: passed
- Installed `Option-Space` key down/up started recording; release did not stop
  the session
- Installed Escape event cancelled the active recording
- TextEdit remained empty after the start/cancel check, proving the configured
  `Option-Space` chord was consumed instead of typing a nonbreaking space
- Settings displayed all required permissions as Granted and the global
  shortcut as Registered
- Shortcut recorder changed the live shortcut to `Control-Option-D` and back
  to `Option-Space`; the saved default remained `Option-Space`

## Human check still required

Synthetic `say` audio was not audible to the selected physical microphone in
the final isolated run, so build 22 still needs one spoken-voice check by the
owner: focus TextEdit, press `Option-Space`, speak, press it again, and confirm
the transcript appears once. Superwhisper was quit for the isolated test because
two dictation apps listening to the same shortcut can both react.
