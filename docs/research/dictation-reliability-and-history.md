# Dictation reliability, recovery, and history patterns

- Date: 2026-08-16
- Scope: crash-safe transcript recovery, popup lifetime, clipboard behavior,
  history retention, optional audio storage, privacy, and insertion confirmation
- Companion research: [Cross-app dictation insertion](cross-app-dictation-insertion.md)
- Evidence rule: product behavior is taken from first-party documentation;
  implementation behavior is taken from commit-pinned source. Recommendations
  and inferences are labeled.

## Recommended product baseline

Guide Companion should treat transcription and delivery as separate durable
stages. The minimum reliable contract is:

1. A completed transcript is atomically persisted **before** the first insert
   attempt.
2. A paste event being posted is not called “inserted.” The result is
   `confirmed`, `unconfirmed`, or `failed`.
3. The non-activating status popup closes automatically only after confirmed
   insertion. Unconfirmed/failed results collapse into a small recovery chip,
   not a screen-blocking panel.
4. **Last Dictation** always offers **Copy**, **Try Again**, and **Delete** after
   an unconfirmed or failed delivery.
5. Default recovery retains one transcript locally for at most 24 hours. It is
   overwritten by the next completed dictation and removed sooner after a
   confirmed insert.
6. Audio history is off by default. If later offered, it is an explicit opt-in
   with finite retention and independent deletion from transcript text.
7. Clipboard restoration is race-safe and preserves all pasteboard item types.
8. No transcript, audio, selected text, window title, or file name is written to
   diagnostic logs or notifications.

This gives the user a no-respeak guarantee without silently building an
indefinite voice-history product.

## Primary-source observations

### Superwhisper: durable history and popup behavior

Observed from official Superwhisper sources:

- Its recording window normally stays open until it detects a successful paste.
  An optional auto-close setting closes it regardless, while leaving the text on
  the clipboard for manual recovery.
  [Advanced Settings: Auto-Close Window](https://superwhisper.com/docs/get-started/settings-advanced#auto-close-window)
- Results still go to the clipboard when both the recording window and automatic
  paste are disabled.
  [Advanced Settings: Paste Result Text](https://superwhisper.com/docs/get-started/settings-advanced#paste-result-text)
- It can restore the pre-dictation clipboard, and it offers simulated keypresses
  as an alternative insertion method.
  [Advanced Settings: Text Input Controls](https://superwhisper.com/docs/get-started/settings-advanced#text-input-controls)
- History includes recordings, original voice transcription, processed text,
  Copy, and reprocessing. Its documentation says history is local and not
  included in FileSync.
  [History](https://superwhisper.com/docs/get-started/interface-history),
  [Sensitive Data Best Practices](https://superwhisper.com/docs/security/sensitive-data#transcription-history)
- The changelog records crash-resilience work: WAV data was saved every 10
  seconds for long recordings; later versions added a configurable recording
  retention setting and fixes for metadata/file-save races.
  [Superwhisper changelog](https://superwhisper.com/changelog)

Documentation drift: the History Management page still says there is no
built-in scheduled cleanup, while the newer 2026 changelog says configurable
recording retention was added. The changelog is newer, but the installed UI
would need verification before relying on its exact options.

Inference: Superwhisper's public behavior provides two distinct recovery
layers—clipboard recovery for immediate delivery failure and local history for
later copy/reprocess. Its private source is unavailable, so its atomic-write
format, confirmation algorithm, and crash boundary cannot be established.

### Pindrop: explicit output states, full history, and finite audio retention

Pindrop is MIT-licensed and source-available. The observations below refer to
commit [`6668d09`](https://github.com/watzon/pindrop/tree/6668d098ac1e1594600d5fdd6c376a1f06aee9a7).

- Its README says every transcript is copied to the clipboard, direct insertion
  is enabled by Accessibility, transcripts are saved automatically, and
  transcript/audio storage is local by default. Its optional telemetry excludes
  transcript text, audio, prompts, and filenames.
  [Pindrop README](https://github.com/watzon/pindrop/blob/6668d098ac1e1594600d5fdd6c376a1f06aee9a7/README.md#usage)
- It snapshots every pasteboard item and representation, performs one clipboard
  paste, waits 500 ms, and restores only when it believes the temporary
  clipboard value still owns the pasteboard. On paste failure it leaves the
  transcript on the clipboard.
  [`OutputManager.swift`](https://github.com/watzon/pindrop/blob/6668d098ac1e1594600d5fdd6c376a1f06aee9a7/Pindrop/Services/OutputManager.swift#L112-L162),
  [`OutputManager.swift`](https://github.com/watzon/pindrop/blob/6668d098ac1e1594600d5fdd6c376a1f06aee9a7/Pindrop/Services/OutputManager.swift#L432-L580)
- Its paste keystroke sends explicit Command-down, V-down, V-up, Command-up
  events with short delays and guarantees a best-effort Command-up on failure.
  This is more defensive than attaching `.maskCommand` to V alone.
  [`OutputManager.swift`](https://github.com/watzon/pindrop/blob/6668d098ac1e1594600d5fdd6c376a1f06aee9a7/Pindrop/Services/OutputManager.swift#L216-L280)
- It distinguishes copy-only mode, missing-Accessibility fallback, and paste
  failure, surfaces an Undo action for clipboard replacement, and tells the user
  when a failed paste has been copied.
  [`OutputManager.swift`](https://github.com/watzon/pindrop/blob/6668d098ac1e1594600d5fdd6c376a1f06aee9a7/Pindrop/Services/OutputManager.swift#L284-L347),
  [`StreamingSessionController.swift`](https://github.com/watzon/pindrop/blob/6668d098ac1e1594600d5fdd6c376a1f06aee9a7/Pindrop/Services/StreamingSessionController.swift#L633-L670)
- Transcript records are saved in SwiftData and contain text, optional original
  text, timestamp, target app identity, and optional managed-audio path.
  [`TranscriptionRecordSchema.swift`](https://github.com/watzon/pindrop/blob/6668d098ac1e1594600d5fdd6c376a1f06aee9a7/Pindrop/Models/TranscriptionRecordSchema.swift#L1820-L1899)
- Dictation-audio retention has off, 7-day, 30-day, and forever options, with 7
  days as the default. Audio encoding runs outside the insertion hot path; the
  sweeper removes expired audio while preserving transcript text.
  [`SettingsStore.swift`](https://github.com/watzon/pindrop/blob/6668d098ac1e1594600d5fdd6c376a1f06aee9a7/Pindrop/Services/SettingsStore.swift#L45-L70),
  [`SettingsStore.swift`](https://github.com/watzon/pindrop/blob/6668d098ac1e1594600d5fdd6c376a1f06aee9a7/Pindrop/Services/SettingsStore.swift#L270-L287),
  [`DictationAudioRetentionService.swift`](https://github.com/watzon/pindrop/blob/6668d098ac1e1594600d5fdd6c376a1f06aee9a7/Pindrop/Services/DictationAudioRetentionService.swift#L374-L424),
  [`DictationAudioRetentionService.swift`](https://github.com/watzon/pindrop/blob/6668d098ac1e1594600d5fdd6c376a1f06aee9a7/Pindrop/Services/DictationAudioRetentionService.swift#L666-L723)

Important limitation: Pindrop defines “pasted” as the paste keystroke being
issued, not the target text being observed. Its normal pipeline also saves the
history record after the output attempt. Therefore it is useful evidence for
clipboard, fallback, and retention patterns, but not a sufficient model for
Guide Companion's insertion confirmation or pre-delivery crash recovery.
[`OutputManager.OutputResult`](https://github.com/watzon/pindrop/blob/6668d098ac1e1594600d5fdd6c376a1f06aee9a7/Pindrop/Services/OutputManager.swift#L284-L319),
[`AppCoordinator.swift`](https://github.com/watzon/pindrop/blob/6668d098ac1e1594600d5fdd6c376a1f06aee9a7/Pindrop/AppCoordinator.swift#L4190-L4246)

### Hold to Talk: per-app strategies and clipboard race defense

The Apache-2.0 Hold to Talk project at commit
[`378b58e`](https://github.com/Edamame-Labs/hold-to-talk/tree/378b58e3f06ba316b993f870694d57631fc576ea)
uses paste first for Electron/browser targets, snapshots all pasteboard item
types, waits 500 ms, and restores only if the pasteboard change count remains
its own.
[`TextInserter.swift`](https://github.com/Edamame-Labs/hold-to-talk/blob/378b58e3f06ba316b993f870694d57631fc576ea/Sources/HoldToTalk/TextInserter.swift#L195-L237),
[`TextInserter.swift`](https://github.com/Edamame-Labs/hold-to-talk/blob/378b58e3f06ba316b993f870694d57631fc576ea/Sources/HoldToTalk/TextInserter.swift#L340-L400)

Important limitation: its current report maps a `tentative` strategy outcome to
`confirmed: true`. Guide Companion should not copy that semantic shortcut.
[`TextInserter.swift`](https://github.com/Edamame-Labs/hold-to-talk/blob/378b58e3f06ba316b993f870694d57631fc576ea/Sources/HoldToTalk/TextInserter.swift#L120-L150)

## Guide Companion reliability design

### Durable state machine

Use a single bounded recovery record with explicit states:

```text
recording
  -> transcribedPendingDelivery   (atomic save completed)
  -> delivering
  -> confirmed | unconfirmed | failed
  -> expired | deleted
```

Required ordering:

1. Finish local transcription.
2. Normalize the final text.
3. Atomically write `transcribedPendingDelivery`.
4. Attempt insertion.
5. Atomically update delivery status and non-content diagnostics.
6. Schedule expiry according to the result.

Apple's atomic data-write option writes to an auxiliary file before replacing
the original, and Application Support is the standard per-app support-data
location. [Apple: atomic data writes](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/atomic),
[Apple: Application Support](https://developer.apple.com/documentation/foundation/url/applicationsupportdirectory)

Recommended record fields:

- schema version and record UUID;
- final transcript;
- created/updated timestamps;
- target bundle ID and PID captured at dictation start;
- delivery state and method;
- redacted failure code; and
- expiry date.

Do not store window titles, document paths, surrounding text, clipboard
snapshots, or audio in this record. Clipboard snapshots remain memory-only.

### Popup lifetime

- **Recording:** small non-activating indicator; never cover the menu bar or
  steal keyboard focus.
- **Processing/delivering:** keep the indicator visible and non-activating.
- **Confirmed:** show success briefly (about 500–800 ms), then dismiss.
- **Unconfirmed:** collapse into a small recovery chip with Copy, Try Again, and
  Dismiss. Do not retry automatically because a second paste could duplicate
  text that actually landed.
- **Failed:** keep the same recovery chip until action/dismissal. The transcript
  remains in Last Dictation even if the chip is dismissed.
- **App relaunch with pending/unconfirmed state:** show a discreet menu-bar badge,
  never a modal popup containing transcript text.

This follows the useful part of Superwhisper's behavior—do not disappear before
success—without reproducing an intrusive always-on-top window.

### Clipboard behavior

1. Capture every pasteboard item/type in memory.
2. Write transcript text and record the resulting `changeCount`.
3. Revalidate the target app.
4. Post one physical Command-V sequence to the frontmost session.
5. Wait a measured app-compatible interval before restoration.
6. Restore the snapshot only if the current `changeCount` exactly equals the
   transcript write's count.

Apple documents `changeCount` as the way to determine whether the caller still
owns the pasteboard. It does not prove another app read the value.
[Apple: `NSPasteboard.changeCount`](https://developer.apple.com/documentation/appkit/nspasteboard/changecount)

Guide Companion policy:

- on confirmed insertion, restore the old clipboard if still owned;
- on unconfirmed insertion, restore the old clipboard if still owned and retain
  the transcript in Last Dictation;
- on failed insertion, do the same and make Copy explicit, rather than silently
  destroying the user's existing clipboard;
- in user-selected copy-only mode, leave the transcript on the clipboard and
  offer Undo restoring the captured snapshot; and
- never restore when `changeCount` changed after the transcript write, because
  that may overwrite a newer user copy.

### Honest insertion confirmation

Three result states are necessary:

- `confirmed`: the target's observable AX text/selection changed exactly as
  expected after insertion;
- `unconfirmed`: the event was posted but the target does not expose enough AX
  state to prove the effect; and
- `failed`: focus changed, event creation/posting failed, the AX target rejected
  the operation, or readable state is unchanged.

Never infer confirmation from:

- successful creation/posting of a `CGEvent`;
- the pasteboard still containing the transcript;
- a delay completing; or
- a target application merely remaining frontmost.

When AX state is readable, capture value and selection before insertion, refetch
the focused element after insertion if necessary, and verify the expected text
at the expected range. When it is not readable, preserve the transcript and ask
for user confirmation/retry rather than automatically pasting twice.

### Retention and privacy defaults

Recommended defaults:

| Data | Default | Expiry | User control |
| --- | --- | --- | --- |
| Last transcript after failure/unconfirmed | On, local | 24 hours or next dictation | Copy, Retry, Delete Now |
| Last transcript after confirmed insert | On briefly | 10 minutes | Delete Now |
| Searchable transcript history | Off | N/A | Separate explicit opt-in later |
| Dictation audio history | Off | N/A | Future opt-in: 24h/7d/30d |
| In-progress temporary audio | Required during capture | Delete after transcript/failure handling | Never sync |
| Diagnostic logs | Metadata only | OS rotation | Export redacted diagnostics |

Store the recovery file under the app's Application Support directory, set
restrictive per-user file permissions, exclude it from backup/sync, and reapply
the exclusion after replacement because Apple notes common file operations can
reset it. [Apple: `isExcludedFromBackupKey`](https://developer.apple.com/documentation/foundation/urlresourcekey/isexcludedfrombackupkey)

Deletion means removing the app's logical record and associated files; do not
promise forensic secure erasure on APFS. If audio retention is added, deletion
must clear both the audio file and any waveform/derived sidecars while leaving
the transcript independently manageable.

## Concrete acceptance recommendations

### Recovery and crash tests

1. Force-quit immediately after transcription and before paste; relaunch must
   expose the exact Last Dictation with Copy/Try Again.
2. Force-quit during the recovery-file replacement; relaunch must show either
   the prior valid record or the new valid record, never a truncated file.
3. Simulate history-save failure; insertion must not begin until the recovery
   slot is durable.
4. Confirmed insertion must expire the slot after the short recovery window.
5. Failed/unconfirmed insertion must survive relaunch and expire after 24 hours.

### Popup and focus tests

6. The indicator never becomes frontmost and never changes the destination PID.
7. Confirmed insertion dismisses promptly.
8. Unconfirmed/failed insertion leaves a non-blocking recovery affordance.
9. Switching apps while transcription runs blocks automatic paste and retains
   Last Dictation.
10. Retry is always user-invoked and never automatically duplicates text.

### Clipboard tests

11. Preserve text, image, file URL, and multi-item clipboard representations.
12. If the user copies new content during the restore delay, the newer clipboard
    remains untouched.
13. Copy-only mode offers Undo and restores every prior item/type.
14. Failed insertion does not erase the old clipboard; explicit Copy works.

### Confirmation matrix

15. Test exact phrases in TextEdit, Notes, Mail, Safari input/contenteditable,
    Chrome input/contenteditable, Slack/Discord, VS Code/Cursor, and Terminal.
16. Record `confirmed`, `unconfirmed`, and `failed` separately; no test may pass
    solely because an event was posted.
17. A secure/password field receives no text and Last Dictation remains
    recoverable without appearing in a notification.
18. Emoji, non-Latin text, multiline text, and large transcripts preserve exact
    Unicode content.

### Privacy tests

19. Search exported logs for a unique dictated canary: zero matches.
20. Verify no recovery or audio file appears in synced/backup locations.
21. Delete Now removes the recovery record; expired audio cleanup removes audio
    plus derived sidecars.
22. No network request occurs in the local dictation, recovery, copy, retry, or
    delete paths.

## Decision implication

The immediate next implementation should be a **Last Dictation recovery slot
and truthful delivery-state model**, followed by session-paste improvements.
Building a full searchable history or retaining audio is not required to solve
the user's reported failure and creates unnecessary privacy scope. The no-respeak
guarantee should be proven first with the crash, clipboard, popup, and cross-app
matrix above.
