# Product Contract

## Outcome

A nontechnical Mac user can install the app, complete a short and understandable
permission flow, dictate text anywhere, and optionally ask for visual guidance
about the app currently on screen.

The core experience remains useful offline and without an account, subscription,
API key, or metered provider.

## First Product Journeys

### Journey A — First local dictation

1. Install and launch the notarized app normally.
2. The app explains and requests Microphone permission.
3. The app explains and requests Accessibility permission only when insertion
   requires it.
4. If a speech model is required, the user sees its language, size, storage
   destination, and download progress.
5. The user focuses a text field, invokes the configurable shortcut, speaks,
   and releases or stops recording.
6. The exact transcript appears at the caret without sending the message or
   invoking an assistant.
7. The same journey works offline after model installation.

### Journey B — Persistent companion

1. The user enables the cursor companion.
2. It appears immediately and remains present across ordinary app switches,
   idle time, settings closure, and failed guidance requests.
3. It does not cover menu-bar controls or intercept clicks outside its visible
   controls.
4. The user can hide it explicitly and the preference survives relaunch.

### Journey C — Ask for screen guidance

1. The user invokes the voice guide from the menu or guide shortcut.
2. The app explains and requests Screen Recording permission if it has not
   already been granted.
3. The cursor companion shows that it is listening; no typing window opens.
4. The user asks a question out loud and invokes the guide again to finish, or
   presses Escape to cancel.
5. For each spoken turn, the app captures only the chosen window/display
   context for that request.
6. The local engine receives recent conversation, structured OCR context, and
   the transient image. Local remains the default. The optional OpenAI Talk
   engine sends only the spoken question, bounded recent Talk text, and exact
   locked-window image after an explicit disclosure and provider selection.
7. The app captions the answer beside the cursor and speaks it locally. An
   optional normal window can show the transient conversation transcript.
8. The user can invoke the guide again and ask a spoken follow-up.
9. It never clicks, types, runs shell commands, or performs the task itself.

## Product Principles

- **Dictation is independent.** Missing assistant configuration can never break
  recording, transcription, or insertion.
- **Local is the default.** OpenAI multimodal Talk is an explicit opt-in and
  never a silent fallback. Ordinary dictation remains local and independent.
- **Permissions follow intent.** Ask only when the user invokes a feature that
  needs the permission.
- **Visible state is truthful.** A control cannot appear enabled while a hidden
  prerequisite prevents it from working.
- **Saved is not verified.** Optional OpenAI Talk requires a recent,
  content-free provider verification before any request may send screen pixels.
- **Failure is actionable.** Every failed turn identifies which stage failed
  and provides a recovery action.
- **The guide advises; it does not operate.** Autonomous agents are outside the
  first product.
- **Privacy is structural.** Screenshots and audio are transient by default.
  One completed transcript is retained briefly for crash and failed-paste
  recovery; longer transcript history and audio history require explicit
  opt-in. Guide conversations remain in memory only and disappear when the app
  quits. Content is never used for analytics or training.

## First-Product Scope

Included:

- Apple Silicon Mac.
- Native concise menu-bar menu plus normal non-floating Settings window.
- The menu bar contains status and primary actions only; onboarding,
  explanations, diagnostics, and manual tests live in Settings.
- Configurable push-to-talk and toggle-dictation shortcuts.
- Free on-device speech-to-text.
- Focused-field insertion with clipboard-preserving fallback.
- Crash-safe Last Dictation recovery with explicit Copy, Retry, and Delete.
- Optional local transcript history; optional audio history is a separate
  opt-in and remains off by default.
- Persistent cursor companion and short captions.
- Explicit, request-scoped voice conversation with local spoken guidance.
- Optional request-scoped OpenAI multimodal Talk, disabled by default, with a
  Keychain-held tester credential and precise send-time disclosure.
- Local logs that redact dictated and captured content.
- Direct-download Developer ID/notarized DMG.

Deferred:

- Wake word and always-listening microphone.
- Autonomous computer use or browser control.
- Shell/file tools, MCP, connected accounts, email, calendars, or child agents.
- Accounts, sync, analytics, billing, collaboration, or hosted history.
- Pets, widgets, galleries, workflow automation, and plugin marketplaces.
- Hosted accounts, bundled/shared provider credentials, subscriptions, and
  automatic provider routing.
- Intel support, Windows, iOS, and Mac App Store distribution.
- Automatic updates until the basic installed-product journey is stable.

## Compatibility Assumption

Plan for Apple Silicon and macOS 14.2 or newer, with acceptance performed first
on the owner's current macOS 26 machine. Newer intelligence APIs must be runtime
feature-gated. Phase 0 may raise the minimum OS only with measured evidence and
an explicit owner decision.

## Product Success

The product is not successful because it builds or displays a cursor. It is
successful when a fresh, signed installation completes the user journeys in
`ACCEPTANCE.md` without Xcode, Terminal, API keys, or undocumented workarounds.
