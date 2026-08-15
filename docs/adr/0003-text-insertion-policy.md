# ADR 0003: Text insertion policy

- Status: accepted for the internal baseline
- Date: 2026-08-16

## Decision

Capture the focused editable Accessibility element when dictation begins.
Insert by selected-value replacement where supported, then use a
clipboard-preserving paste into the captured process as the fallback.

## Safety properties

- Revalidate the captured process before insertion.
- Never press Return or submit a form.
- Restore the prior clipboard after fallback paste.
- Cancellation never calls the insertion adapter.
- Report unsupported targets instead of silently dropping text.
