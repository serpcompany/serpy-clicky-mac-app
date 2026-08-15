# ADR 0005: Crash-Safe Dictation Recovery and Optional History

## Status

Accepted for build 17.

## Context

A completed local transcription can be lost after recognition succeeds but
before another application accepts a paste. Applications may lag, reject
synthetic input, change focus, or become unresponsive. A popup that exists only
in memory also disappears if Guide Companion crashes or is relaunched.

Superwhisper's documented behavior keeps results recoverable when pasting does
not complete, and mature open-source dictation apps snapshot and restore the
pasteboard. Their internals do not provide a reliable universal paste-success
signal, so event delivery alone cannot be treated as confirmation. See
`docs/research/dictation-reliability-and-history.md`.

## Decision

1. Atomically persist the final transcript before any insertion attempt.
2. By default, retain only the newest Last Dictation. Expire confirmed delivery
   after 10 minutes and unconfirmed or failed delivery after 24 hours.
3. Label delivery `confirmed` only when the target value can be observed to
   change. A posted paste event is `unconfirmed`.
4. Keep unconfirmed and failed results available through nonblocking Copy,
   Retry, and Delete actions.
5. An unchanged Accessibility value does not prove failure: Electron and code
   editors may expose a stable instructional placeholder instead of document
   text. Treat those deliveries as unconfirmed and preserve recovery.
6. Preserve all pasteboard items and representations and restore them only if
   the pasteboard change count still proves ownership.
7. Offer full local text history as an opt-in, bounded to 25 entries and 30
   days. Offer audio history as a second, independent opt-in.
8. Store files with owner-only permissions, exclude them from backup, and never
   log transcript, audio, screen, window-title, or file-path content.

## Consequences

The default is not zero-persistence: reliability requires one short-lived local
recovery record. The Settings UI must disclose this plainly. Longer history and
audio accumulation remain disabled until the user chooses them. Delivery status
is more conservative but truthful in applications where macOS does not expose
the edited value.
