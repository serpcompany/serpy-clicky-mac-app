# Yap durable Dictation import record

- Upstream: `https://github.com/FrigadeHQ/yap`
- Revision: `5f06bb1aa889abaa064b09a9bf33aff984dc1583`
- Disposition: adapted
- Downstream scope: Version 1 Dictation reliability on macOS 26

## Imported and derived units

| Upstream path | Symbols/behavior | Downstream path |
| --- | --- | --- |
| `Sources/Coordinator/RecordingCoordinator.swift` | `RecordingCoordinator`, injected `DictationSessioning`, target capture before product UI, owned start/stop phases | `Packages/GuideModules/Sources/GuideCore/RecordingCoordinator.swift` |
| `Sources/Services/DictationSession.swift` | `DictationSessioning`, `DictationSession`, microphone-first startup, early-buffer relay | `Packages/GuideModules/Sources/GuideCore/StreamingTranscription.swift`; `Packages/GuideModules/Sources/GuideMac/DurableDictationSession.swift` |
| `Sources/Services/StreamingTranscriber.swift` | `StreamingTranscriber` interface | `Packages/GuideModules/Sources/GuideMac/StreamingTranscribers.swift` |
| `Sources/Services/TranscriptionService.swift` | `SpeechAnalyzer`, `SpeechTranscriber`, finalized-prefix plus volatile-suffix accumulation | `Packages/GuideModules/Sources/GuideCore/StreamingTranscription.swift`; `Packages/GuideModules/Sources/GuideMac/StreamingTranscribers.swift` |
| `Sources/Services/AudioBufferRelay.swift` | lock-protected bounded early-buffer relay | `Packages/GuideModules/Sources/GuideMac/AudioBufferRelay.swift` (`AudioBufferRelay`) |
| `Sources/Services/AudioCaptureService.swift` | fresh AVAudioEngine graph after input-device configuration changes | `Packages/GuideModules/Sources/GuideMac/AudioCaptureService.swift` (`YapAudioCaptureService`) |
| `Sources/Services/BufferConverter.swift` | AVAudioConverter lifecycle and single-consumption input block | `Packages/GuideModules/Sources/GuideMac/StreamingTranscribers.swift` (`BufferConverter`) |
| `Sources/Services/SpeechLocale.swift` | deterministic exact, language-region, then language-only locale matching | `Packages/GuideModules/Sources/GuideMac/StreamingTranscribers.swift` |
| `Tests/RecordingCoordinatorTests.swift` | injected behavior-test structure, original-target capture, cancel-without-insert | `Packages/GuideModules/Tests/GuideCoreTests/RecordingCoordinatorTests.swift` |

Pinned source: <https://github.com/FrigadeHQ/yap/tree/5f06bb1aa889abaa064b09a9bf33aff984dc1583>

## Serpy-specific modifications

- Moved provider-neutral transcript/result, target, insertion, and Last
  Dictation interfaces into `GuideCore`; AppKit/Speech/AVFoundation remain in
  `GuideMac`.
- Preserved serpy's existing focused PID/AX target and revalidation rather than
  Yap's injector implementation.
- Persist the completed transcript before delivery. Yap saves history after
  injection; that ordering was not imported.
- Preserved serpy's confirmed, unconfirmed, and failed delivery states and
  bounded Last Dictation retention.
- Added explicit ownership/cancellation for the full transcription, persistence,
  and insertion attempt. Late results are rejected by attempt identity.
- Added every-buffer owner-only raw-audio checkpoints, explicit checkpoint
  failure, discoverable interrupted audio, and recovery into pending Last
  Dictation without automatic insertion.
- Use only already-installed Apple Speech assets during Dictation. Yap's asset
  download/install behavior was removed so automated or ordinary activation
  cannot begin an undocumented download.
- On macOS 14–25, transcribe the durable checkpoint through sequential
  sub-minute on-device `SFSpeechURLRecognitionRequest` chunks. This serpy-only
  glue prevents the donor's macOS 26 requirement from leaving supported older
  systems on the previous one-request limit.
- Omitted dictionary, filler removal, model cleanup, history UI, sounds, HUD,
  settings, secure-input UI, and product identity.

## Dependencies

Retained system frameworks only: `Speech`, `AVFoundation`, `Foundation`, and
`os`. No Yap package dependency was added. No upstream third-party dependency,
asset, model, endpoint, credential, analytics, signing setting, bundle ID,
release configuration, or update feed was retained.

## Regression tests

- `StreamingTranscriptAccumulatorTests`: finalized/volatile semantics and five
  ordered sentinels spanning the one-minute boundary.
- `RecordingCoordinatorTests`: immediate preparing acknowledgement,
  preserve-before-delivery ordering, checkpoint failure, cancellation/late
  output suppression including pending insertion, truthful unconfirmed
  recovery, and all interrupted-audio recovery without insertion.
- `RecoveryAudioCheckpointWriterTests`: every-buffer checkpoint frequency,
  explicit write failure, and discoverable/cancellable interrupted audio.
- `DurableDictationSessionTests`: 130 seconds of real PCM with encoded sentinel
  markers, injected recognition/device failures, all-checkpoint recovery,
  visible deletion failure, and macOS 14–25 sub-minute chunking.
- `DictationAdapterContractTests`: production conformance to the external
  capture, session, streaming, target, insertion, and recovery seams.

## MIT notice

MIT License

Copyright (c) 2026 Frigade, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
