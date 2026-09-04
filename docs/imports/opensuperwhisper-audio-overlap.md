# OpenSuperWhisper audio-boundary overlap import record

- Upstream: `https://github.com/Starmel/OpenSuperWhisper`
- Revision: `bef6bc0421d0c010e8f2fb4288c0d74978c8b964`
- Disposition: adapted
- Downstream scope: macOS 14–25 long-session chunk boundaries

## Imported and derived behavior

OpenSuperWhisper's `WhisperEngine.speechOnlySamples` deliberately retains a
bounded overlap across VAD segment boundaries so words at a cut are not lost.
Pinned source:
<https://github.com/Starmel/OpenSuperWhisper/blob/bef6bc0421d0c010e8f2fb4288c0d74978c8b964/OpenSuperWhisper/Engines/WhisperEngine.swift#L250-L270>.

Serpy adapts that proven overlap principle in:

- `Packages/GuideModules/Sources/GuideMac/StreamingTranscribers.swift`
  (`ChunkedSFSpeechTranscriber.splitIfNeeded`), using a bounded one-second
  overlap between sub-minute `SFSpeechRecognizer` requests; and
- `Packages/GuideModules/Sources/GuideCore/TranscriptOverlapReconciler.swift`,
  removing the largest exact word suffix/prefix so overlap cannot duplicate the
  transcript boundary.

The donor's Whisper/VAD engine, model code, settings, product identity, assets,
dependencies, credentials, signing, services, and release configuration were
not imported.

Regression coverage:

- `TranscriptOverlapReconcilerTests`
- `DurableDictationSessionTests.legacyBoundaryOverlapDoesNotLoseOrDuplicateWords`

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
