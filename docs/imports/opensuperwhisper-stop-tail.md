# OpenSuperWhisper stop-tail import record

- Upstream: `https://github.com/Starmel/OpenSuperWhisper`
- Revision: `bef6bc0421d0c010e8f2fb4288c0d74978c8b964`
- Disposition: adapted
- Downstream scope: cancellable final-word tail for Version 1 Dictation

## Imported and derived unit

- Upstream path: `OpenSuperWhisper/AudioRecorder.swift`
- Upstream symbols: `AudioRecorder.stopTailDuration`, `stopRecording`, and the
  delayed stop closure at lines 215–249.
- Downstream paths: `Packages/GuideModules/Sources/GuideCore/StreamingTranscription.swift`
  and `Packages/GuideModules/Sources/GuideMac/DurableDictationSession.swift`.
- Downstream symbols: `DictationStopTail.wait/cancel` and
  `DurableDictationSession.stop/cancel`.
- Pinned source: <https://github.com/Starmel/OpenSuperWhisper/blob/bef6bc0421d0c010e8f2fb4288c0d74978c8b964/OpenSuperWhisper/AudioRecorder.swift#L215-L249>

## Serpy-specific modifications

- Retained the bounded 250-millisecond capture tail before stopping the audio
  input.
- Made the wait an owned Swift task so Escape/termination cancels it.
- Kept serpy's SpeechAnalyzer streaming, recovery checkpoints, focused target,
  preserve-before-delivery, and delivery-state behavior.
- Did not import microphone switching, notification sounds, UI, preferences,
  assets, models, identity, signing, or release configuration.

## Dependencies and tests

No OpenSuperWhisper dependency was added. Only system framework behavior is
used. Cancellation and late-output suppression are protected through
`RecordingCoordinatorTests`; the final spoken-word result remains an installed
artifact acceptance check.

## MIT notice

MIT License

Copyright (c) 2024 OpenSuperWhisper

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
