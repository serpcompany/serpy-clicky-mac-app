# Decision Ledger

| ID | Decision | Status | Current recommendation | Revisit trigger |
| --- | --- | --- | --- | --- |
| D-001 | First product is guide-only, not autonomous | Approved by owner | Dictation + companion + explicit screen guidance | Installed baseline passes and owner asks for agents |
| D-002 | Production base | Recommended | Fresh independent repo with selective audited reuse | Phase 0 shows an OpenClicky subsystem is both isolated and superior |
| D-003 | Core economics | Approved from prior requirements | Offline/no-key dictation is mandatory | None; foundational product contract |
| D-004 | CPU/OS floor | Assumption | Apple Silicon, plan for macOS 14.2+, test first on macOS 26 | Phase 0 framework measurements |
| D-005 | Speech runtime | Provisional implementation | Apple on-device Speech for the first installed baseline; retain adapter seam | Offline HIL or latency/accuracy fails acceptance |
| D-006 | Local guidance runtime | Provisional implementation | ScreenCaptureKit + Vision OCR + Apple Foundation Models on macOS 26 | Local model unavailable or scenario HIL fails |
| D-007 | Distribution | Recommended | Developer ID notarized direct DMG | Owner chooses Mac App Store or dual channel |
| D-008 | Product name and visual identity | Internal baseline | `Guide Companion`, tester-owned bundle ID, and original generated icon | Commercial naming decision before public distribution |
| D-009 | Automatic updates | Deferred | No update framework in first slices | Installed baseline stabilizes |
| D-010 | Cloud providers | Deferred | No cloud provider in core path | Owner explicitly approves optional cloud tier |
| D-011 | Implementation through installed baseline | Approved by owner | Execute Phases 0–4 and deliver a notarized internal DMG | Public distribution remains separately approval-gated |

Owner decisions must be recorded here before they become implementation
assumptions.
