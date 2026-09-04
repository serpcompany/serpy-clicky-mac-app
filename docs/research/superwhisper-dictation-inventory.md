# Superwhisper Dictation reference inventory

- Date: 2026-09-04
- Scope: existing Dictation functionality for serpy Version 1
- Reference app: `/Applications/superwhisper.app`
- Bundle identifier: `com.superduper.superwhisper`
- Version/build: `2.18.3 (2.18.3)`
- Minimum macOS: 14.0
- Architectures: `x86_64`, `arm64`
- Executable SHA-256: `6e6c36b4d410f854889e025c5e97f1fe59632677f410896956fe6d238dfcaf2a`
- Signature: Developer ID Application, team `XDP69BYUP9`
- Target product: serpy, preserving its existing technical identity

## Evidence boundary

The installed app and official documentation are behavioral/product oracles.
They do not expose Superwhisper's private implementation. Agents may observe
normal UI and public behavior, but may not decompile the app, copy private data,
or infer hidden implementation from screenshots.

Implementation should remain source-first rather than agent-invented. Use a
licensed open-source Dictation donor where source is required, document exact
imports under `docs/imports/`, and write only the serpy-specific integration
needed to preserve its local/privacy/recovery requirements.

Primary external references:

- [Saved product reference](../reference/superwhisper-product.md)
- [Official introduction](https://superwhisper.com/docs/get-started/introduction)
- [Product landing page](https://superwhisper.com/)
- [OpenSuperWhisper](https://github.com/Starmel/OpenSuperWhisper), MIT candidate
  donor for native recording, transcription, shortcut, microphone, and
  clipboard behavior
- [open-wispr](https://github.com/human37/open-wispr), MIT secondary candidate
  for test-backed lifecycle and insertion behavior

## Captured settings surfaces

All committed images are direct captures of the installed reference window at
750×1060. They document information architecture and controls, not a Version 1
requirement to reproduce the entire Settings design.

### Home

![Superwhisper Home](images/superwhisper/home.jpg)

Observed: persistent left navigation, current microphone in the window header,
license/trial state, product/community actions, and a bottom promotional card.
Licensing, purchasing, community links, and promotions are outside Version 1.

### Modes

![Superwhisper Modes](images/superwhisper/modes.jpg)

Observed: named modes, an active/default indicator, provider/model badges,
create-mode action, mode testing, and a global change-mode shortcut. Version 1
requires the existing plain Dictation path; custom mode creation and cloud text
processing are later features.

### Vocabulary

The supplied Vocabulary capture is intentionally not committed because it
contains an email address and user-specific vocabulary. Its nonprivate structure
is recorded here:

- left-navigation destination;
- one field for a new word or replacement;
- separate Add word and Replace with actions with keyboard equivalents;
- CSV import action; and
- a list of configured words/replacements.

Vocabulary behavior is a later feature, not a Version 1 stabilization gate.

### Configuration

![Superwhisper Configuration](images/superwhisper/configuration.jpg)

Observed:

- Auto, Light, and Dark appearance;
- Classic, Mini, and None recording-window choices;
- Always show toggle;
- Toggle Recording shortcut with start/stop semantics;
- Escape cancellation that discards the active recording;
- change-mode shortcut;
- Push to Talk using hold/release semantics;
- optional mouse shortcut;
- update checking, launch on login, error logging, recording retention, and an
  Advanced settings destination.

Version 1 functional reference: toggle/hold activation, immediate recording
feedback, Escape cancellation, and predictable cleanup. Settings redesign,
mouse activation, update UI, launch-on-login, and additional options are later.

### Sound

![Superwhisper Sound](images/superwhisper/sound.jpg)

Observed: current microphone, automatic microphone-volume adjustment, silence
removal, dynamic normalization, playback behavior while recording, selectable
recording sound effects, and volume control.

Version 1 functional reference: microphone readiness, complete-word capture,
and audible start/stop feedback if already present. Adding new sound controls or
signal processing is later work.

### Models library

![Superwhisper Models library](images/superwhisper/models-library.jpg)

![Superwhisper local voice models](images/superwhisper/models-library-local.jpg)

Observed: searchable/filterable provider list, separate voice/text model types,
relative speed/accuracy indicators, cloud/offline status, favorite state,
download/delete actions, and local sizes including Parakeet and Whisper models.

Version 1 uses the existing serpy local engine. Model-library parity, additional
providers, downloads, ranking, and cloud processing are later work.

### History

The supplied History capture is intentionally not committed because it contains
private dictated text. Its nonprivate structure is recorded here:

- history search;
- dated recording groups;
- transcript preview;
- audio playback with waveform and duration;
- Original and Segmented views;
- Copy transcript;
- reprocess actions;
- recording information; and
- deletion.

Version 1 stabilizes serpy's existing Last Dictation recovery only. Full
Superwhisper-style History parity and changed retention defaults are later.

## Version 1 behavior to reproduce

This is the smallest Superwhisper-style acceptance unit for existing serpy
Dictation:

1. Keep TextEdit or Chrome frontmost.
2. Invoke the existing Dictation shortcut using toggle or the already-supported
   hold/release behavior.
3. Show immediate compact recording state without activating serpy.
4. Capture the complete utterance, including the final word at shortcut release.
5. Transcribe using the existing local engine.
6. Insert the exact result at the previously focused destination without
   submitting it.
7. Preserve every representation of the prior clipboard unless the user makes a
   newer clipboard change.
8. Escape cancels and discards the active attempt; late callbacks cannot insert.
9. Failed or unconfirmed delivery leaves the existing Last Dictation recovery
   available.
10. Quit/relaunch leaves one app instance and no repeated permission prompt.

## Source-first implementation rule

Before creating a new Dictation abstraction, the implementation agent must map
each failing behavior to existing serpy code and to a licensed donor unit.

Adopt when a donor already supplies the required behavior. Adapt only for serpy
module boundaries, local-provider choice, privacy, recovery, and stable app
identity. Write a new unit only when the import map demonstrates that neither
donor provides the required behavior.

The previously proposed `DictationSessionCoordinator` is not approved as a
preselected design. Its need and shape, if any, must emerge from the donor import
map rather than from refactoring preference.

## Privacy and capture notes

- The user supplied all seven Settings screen descriptions.
- Six privacy-safe screens were recaptured and committed.
- Vocabulary and History images remain uncommitted because they contain an email
  address, user vocabulary, and dictated content.
- No recording was started and no dictation, microphone input, clipboard change,
  model download, account action, or deletion was performed during this pass.
