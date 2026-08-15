# Cross-app dictation insertion on macOS

- Date: 2026-08-16
- Scope: stable delivery of an already-produced transcript into the user's
  focused macOS app, plus recovery when delivery cannot be confirmed
- Evidence policy: primary sources only; observed facts and architectural
  inferences are labeled separately

## Executive finding

Guide Companion should not treat a successful Accessibility write or a posted
keyboard event as proof that text reached the destination. A more resilient
baseline is:

1. capture the destination app when recording begins without taking focus;
2. persist the completed transcript into a single local recovery slot before
   attempting insertion;
3. revalidate that the same app is frontmost;
4. use normal clipboard paste as the broad default delivery path;
5. restore the prior clipboard only if nobody else changed it during the paste;
6. verify the destination through Accessibility when the target exposes enough
   state, otherwise report the paste as *unconfirmed* rather than successful;
7. retain an explicit **Last Dictation** action with **Copy** and **Try Again**
   so a failed paste never forces the user to speak again; and
8. keep simulated Unicode typing as an opt-in/per-app fallback.

This is consistent with Superwhisper's documented product behavior and with a
current open-source macOS dictation implementation, while avoiding claims about
Superwhisper's private implementation.

## What Superwhisper documents

### Observed facts

- Its recording window normally remains open until it detects a successful
  paste. If it closes without success, the dictated text remains on the
  clipboard for manual pasting. [Superwhisper Advanced Settings](https://superwhisper.com/docs/get-started/settings-advanced#auto-close-window)
- It has a **Paste Result Text** option. Even when automatic paste and the
  recording window are both disabled, it still puts the result on the
  clipboard. [Superwhisper Advanced Settings](https://superwhisper.com/docs/get-started/settings-advanced#paste-result-text)
- Its **Restore Clipboard** option restores the clipboard content that existed
  before dictation. [Superwhisper Advanced Settings](https://superwhisper.com/docs/get-started/settings-advanced#restore-clipboard)
- Its **Simulate Keypresses** option is an alternative for apps where direct
  paste is blocked by privacy settings or application restrictions.
  [Superwhisper Advanced Settings](https://superwhisper.com/docs/get-started/settings-advanced#simulate-keypresses)
- Its History UI retains recordings and both the original and processed text,
  offers Copy and Process Again, and does not automatically delete prior
  recordings. [Superwhisper History](https://superwhisper.com/docs/get-started/interface-history),
  [History Management](https://superwhisper.com/docs/get-started/history-management)

### Inference from those facts

Superwhisper appears to separate transcription from delivery: it can preserve
the result independently of whether automatic insertion succeeds, it has some
form of paste-success detector, and it offers a second text-input mechanism.
That separation is the important behavior to reproduce.

### What cannot be known from public documentation

Superwhisper is not source-available. Its documentation does **not** establish:

- whether “direct paste” means a menu command, Accessibility action, Apple
  event, `CGEvent` Command-V, or a mixture;
- which event-tap location it uses;
- whether it captures an Accessibility element or only the destination PID;
- how it detects a successful paste in native, Electron, browser
  `contenteditable`, terminal, or remote-desktop fields;
- its delays, retries, app-specific profiles, secure-input checks, or clipboard
  race handling; or
- its on-disk file format and crash-consistency guarantees.

Any assertion about those internals would be speculation.

## Why direct Accessibility writes vary by app

### Apple API facts

- The system-wide `AXFocusedApplication` is the app currently accepting
  keyboard input, and that app can then be queried for its focused UI element.
  [Apple: `kAXFocusedApplicationAttribute`](https://developer.apple.com/documentation/applicationservices/kaxfocusedapplicationattribute)
- `AXSelectedText` and `AXSelectedTextRange` are specified for editable text
  elements. [Apple: Accessibility text attributes](https://developer.apple.com/documentation/applicationservices/carbon_accessibility/attributes)
- An Accessibility attribute is writable only when the target app exposes a
  setter. Apple explicitly describes custom controls as responsible for
  exposing their accessibility information, properties, and actions.
  [Apple: `NSAccessibility`](https://developer.apple.com/documentation/appkit/nsaccessibilityprotocol)
- `AXUIElementSetAttributeValue` can fail with `attributeUnsupported`,
  `cannotComplete`, or `notImplemented`, among other errors.
  [Apple: `AXUIElementSetAttributeValue`](https://developer.apple.com/documentation/applicationservices/axuielementsetattributevalue(_:_:_:))

### Inference

There is no single reliable AX mutation path across AppKit controls, custom
editors, browser content-editable surfaces, Electron, terminals, and remote
desktops. Even when an AX value is settable, replacing the value is not
necessarily equivalent to the destination app receiving its normal Paste or
keyboard input path. An editor may also represent its selection with text
markers rather than a simple string and `CFRange`.

Therefore AX should be used to identify and, where possible, observe the target.
It should not be the universal first-choice insertion mechanism. A direct AX
write is reasonable only for target profiles where it is known to work and its
effect can be read back.

## Recommended insertion pipeline

### 1. Capture without stealing focus

At hotkey-down, record:

- `NSWorkspace.shared.frontmostApplication` PID and bundle identifier;
- the system Accessibility focused application and focused element when
  available; and
- a non-content target description such as role/subrole for diagnostics.

Apple defines the frontmost application as the app that receives key events.
[Apple: `NSWorkspace.frontmostApplication`](https://developer.apple.com/documentation/appkit/nsworkspace/frontmostapplication)
The companion HUD/settings window must be non-activating during recording, or
the app will capture itself rather than the destination.

### 2. Persist before attempting delivery

Once transcription completes and before touching the clipboard or sending an
event, atomically write a single recovery record containing:

- transcript text;
- creation time;
- target bundle identifier (not window title or document content);
- insertion state: `pending`, `confirmed`, `unconfirmed`, or `failed`; and
- the attempted delivery method and redacted error code.

Do not store microphone audio for this recovery feature. The saved record is
the safety net if the app crashes or the paste goes to the wrong place.

### 3. Revalidate focus

Immediately before insertion:

- require `NSWorkspace.frontmostApplication.processIdentifier` to match the
  captured target PID;
- when AX is available, require the focused AX application PID to match too;
- reject the app's own PID and secure/password fields; and
- if focus changed, do not reactivate an old app and paste unexpectedly. Mark
  the result failed and present **Copy** / **Try Again in Current Field**.

The user can intentionally choose Try Again after returning focus. Automatic
reactivation is dangerous because a delayed transcript could land in an
unrelated conversation or form.

### 4. Paste through the normal frontmost event stream

For the broad default path:

1. Snapshot every general-pasteboard item and every data representation/type.
   The pasteboard is shared between apps and may contain multiple items and
   representations. [Apple: `NSPasteboard`](https://developer.apple.com/documentation/appkit/nspasteboard)
2. Record the initial `changeCount`.
3. Replace the pasteboard with the transcript as plain text and record the new
   `changeCount`.
4. Revalidate the target app once more.
5. Post Command-V into the session event stream so macOS routes it to the
   frontmost responder, instead of targeting a PID that may not own the actual
   editor surface. Apple documents `CGEvent.post(tap:)` as posting into the
   Quartz event stream. [Apple: `CGEvent.post(tap:)`](https://developer.apple.com/documentation/coregraphics/cgevent/post(tap:))
6. Allow the destination time to consume the pasteboard before restoration;
   start with 400–500 ms and measure per app.
7. Restore the snapshot only when the current `changeCount` still equals the
   transcript write's count. Apple explicitly says `changeCount` can determine
   whether the caller still owns the pasteboard.
   [Apple: `NSPasteboard.changeCount`](https://developer.apple.com/documentation/appkit/nspasteboard/changecount)

If the count changed, another app or the user changed the clipboard. Do not
overwrite that newer content.

`changeCount` is a clipboard-ownership/race guard, **not** proof that the target
accepted the paste: a reader need not take pasteboard ownership.

### 5. Verify honestly

- When the AX target exposes value/selection state, snapshot it and read it back
  after paste. Confirm only if the expected insertion is observable.
- If the AX element became invalid, re-fetch the currently focused element from
  the already-verified target process before reading back.
- When a target does not expose readable text, label the delivery
  `unconfirmed`. Do not equate successful event creation/posting with successful
  insertion.
- Keep the recovery record and a small visible “Copied / insertion unconfirmed”
  state until the user dismisses it, copies it, or retries.

Superwhisper documents successful-paste detection but not how it works. Guide
Companion will need a target matrix and more than one confirmation method.

### 6. Fallback strategies

1. **Normal paste**: default for browsers, Electron apps, and unknown targets.
2. **Verified AX selected-text write**: optional per-app optimization for
   controls proven to support it; read back before calling it confirmed.
3. **Simulated Unicode/keycode typing**: opt-in or per-app fallback when paste
   is blocked. Apple warns that application frameworks may ignore a Unicode
   string attached to a keyboard event and translate the virtual key code
   themselves. [Apple: `keyboardSetUnicodeString`](https://developer.apple.com/documentation/coregraphics/cgevent/keyboardsetunicodestring(stringlength:unicodestring:))
4. **Clipboard-only recovery**: always available through an explicit Copy
   action, even without Accessibility permission.

The Apache-2.0 Hold to Talk project provides useful corroborating source, not a
claim about Superwhisper: it chooses paste first for Electron and browser bundle
IDs, uses Unicode/keycode strategies for native apps, snapshots all clipboard
items and types, posts Command-V, waits up to 500 ms, and restores only if the
pasteboard change count is still its own. See commit
[`378b58e`, `TextInserter.swift`](https://github.com/Edamame-Labs/hold-to-talk/blob/378b58e3f06ba316b993f870694d57631fc576ea/Sources/HoldToTalk/TextInserter.swift#L195-L399).

## Bounded Last Dictation recovery

The user requirement is recovery from delivery failure, not an indefinite
surveillance-style history. Recommended default:

- retain exactly one transcript, locally, and overwrite it on the next completed
  dictation;
- write it atomically before insertion so a crash cannot erase it;
- expose **Last Dictation** from the menu bar with **Copy**, **Try Again**, and
  **Delete Now**;
- keep it after failed or unconfirmed insertion;
- automatically delete it 24 hours after creation, and clear it immediately on
  explicit deletion;
- after a confirmed insertion, retain it only for a short undo/recovery window
  (for example 10 minutes), then delete it;
- exclude it from cloud/file sync and backups, use a per-user Application
  Support location with restrictive file permissions, and never include its
  contents in logs or notifications; and
- make longer searchable history a separate, explicit opt-in product decision.

This is intentionally more privacy-preserving than Superwhisper's documented
default, which retains recordings and associated transcription data until the
user deletes them.

## Acceptance matrix for the next build

The insertion change is not complete after TextEdit alone. Test the signed,
installed app with a unique phrase in each target:

| Target | Expected default | Evidence |
| --- | --- | --- |
| TextEdit | paste or verified AX | exact phrase at caret |
| Notes | normal paste | exact phrase at caret |
| Mail compose | normal paste | exact phrase in body, no send |
| Safari plain input | normal paste | exact phrase, field remains focused |
| Safari contenteditable | normal paste | exact phrase, editor state updates |
| Chrome input/contenteditable | normal paste | exact phrase |
| Slack/Discord | normal paste | exact phrase, no auto-send |
| VS Code/Cursor editor | normal paste | exact phrase, no duplication |
| Terminal/iTerm | explicit profile | exact phrase at prompt, no execution |
| password/secure field | blocked | no insertion; recovery remains available |
| focus switched during transcription | blocked | no paste into new/old app |

For every row also test:

- a preexisting clipboard containing text plus a non-text representation;
- copying something else during insertion (the newer clipboard must win);
- an emoji, accented text, and multi-line text;
- insertion failure followed by **Copy** and **Try Again**; and
- app relaunch after an unconfirmed paste, proving Last Dictation recovery.

## Consequence for the existing ADR

ADR 0003 currently selects direct Accessibility replacement first and a
PID-targeted paste second. The evidence above supports revising that decision:
use focus-verified session paste as the general default, reserve direct AX writes
for verified profiles, and make durable Last Dictation recovery part of the
insertion contract rather than an error-message suggestion.
