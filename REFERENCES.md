# Reference Scout

References provide partial patterns, not an architecture to copy wholesale.

| Reference | Trust and fit | Adopt/adapt | Caveat |
| --- | --- | --- | --- |
| [Apple ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit) | Platform authority for request-scoped macOS capture and system content selection | Adopt platform permission and capture primitives | OS versions differ; validate against the supported deployment target |
| [Apple Foundation Models](https://developer.apple.com/documentation/foundationmodels) | Platform authority for Apple on-device language models | Adapt behind `GuidanceGenerating` | Availability depends on OS, hardware, Apple Intelligence state, language, and downloaded model |
| [Apple Application Services](https://developer.apple.com/documentation/applicationservices) | Platform authority for Accessibility APIs | Adopt AX primitives behind narrow adapters | Application support varies; preserve a tested fallback chain |
| [Argmax OSS / WhisperKit](https://github.com/argmaxinc/argmax-oss-swift) | MIT Swift-native on-device speech stack supporting macOS 14+ | Evaluate as primary local STT candidate | Model download size, runtime cost, SDK evolution, and third-party notices require measurement |
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | Mature MIT Swift library for user-configurable global shortcuts | Evaluate rather than hand-building shortcut recording UI | Modifier-only push-to-talk semantics may still require a dedicated event tap |
| [Aiyo Wisper](https://github.com/Aiyo28/aiyo-wisper) | Small open-source macOS example with audio, transcription, insertion, model, permission, and overlay boundaries | Learn from its system shape during Phase 0 | Young project with limited adoption; not a production authority |
| [HeyClicky](https://www.hiclicky.com/) | Shipped behavioral reference for voice, screen context, and visual guidance | Adopt only the high-level journeys and interaction expectations | Proprietary implementation and identity are off limits |
| [OpenClicky](https://github.com/jasonkneen/openclicky) | MIT source with working macOS permissions, transcription, overlays, packaging, and broad integrations | Audit narrow components and adapt tested edge cases | Approximately 90k Swift LOC in the pinned checkout; broad coupling and inherited product scope |
| [Superwhisper voice documentation](https://superwhisper.com/docs/modes/voice) | Shipped behavior reference for transcription-only voice mode | Adopt separation of raw dictation from language-model processing | Proprietary implementation; behavior and docs only |

## Local Evidence

| Evidence | Lesson carried forward |
| --- | --- |
| OpenClicky issues 1–8 in `devinschumacher/openclicky-internal-releases` | Avoid hover-obstructing UI, floating Settings, silent provider failure, coupled onboarding, disappearing cursor, and paid-key core paths |
| `/Users/devin/dev/repos/TEMP-openclicky-proj/evidence/phase-1-report.md` | Reuse the proven direct-download, notarization, quarantine, Finder-install, and relaunch verification discipline |
| `/Users/devin/dev/repos/clone-keylume-ios-app/docs/architecture.md` | Keep domain state independent from macOS adapters and presentation |
| Prior HeyClicky presentation experiment | Preserve geometry, lifecycle, and screenshot/HIL evidence patterns; do not treat the branch as production architecture |

## Evidence That Would Change This Plan

- If no local guidance engine produces useful answers on the target Mac, Phase 3
  must narrow to deterministic OCR/Accessibility guidance or require a separate
  owner decision about an optional cloud tier.
- If a broadly compatible direct Accessibility insertion route proves reliable,
  pasteboard fallback can become exceptional rather than normal.
- If macOS 14.2 prevents safe content selection or the chosen local runtime,
  the minimum OS may rise after the owner reviews measured impact.
- If an OpenClicky component is genuinely isolated, well-tested, and smaller
  than a new implementation, its import can be approved through PROVENANCE.md.
