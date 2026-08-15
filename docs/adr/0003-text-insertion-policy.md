# ADR 0003: Text insertion policy

- Status: accepted for the internal baseline
- Date: 2026-08-16

## Decision

Capture the frontmost process and its focused Accessibility element, when one
is available, when dictation begins. Use a normal clipboard-preserving
Command-V in the frontmost session as the default insertion path. Use direct
Accessibility writes only as fallbacks and accept them only when a readback
confirms the destination changed.

Preserve every nonempty completed transcript in a single in-memory Last
Dictation slot before attempting delivery. Expose Retry, Copy, and Clear so an
insertion failure never requires the user to dictate the same text again.

## Safety properties

- Revalidate the captured process before and after insertion.
- Never press Return or submit a form.
- Snapshot every pasteboard item and representation. Restore the prior
  clipboard only when its change count proves nobody else changed it.
- Cancellation never calls the insertion adapter.
- Do not trust a successful AX return code without observable readback.
- Report unsupported or unconfirmed targets instead of silently dropping text.
- Retain Last Dictation until the user clears it or the app quits.
