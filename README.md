# serpy for macOS

serpy is a small native macOS companion for private, on-device dictation and
optional screen guidance.

The first product must do two things well:

1. Dictate ordinary speech into the focused text field using a free local
   speech model, with no assistant request and no API key.
2. Provide an optional cursor companion that can explain the current screen and
   point to a suggested next step without taking autonomous action.

Installed HeyClicky is the UX/behavior reference. The historical MIT-licensed
`farzaa/clicky` revision pinned in `PROVENANCE.md` is an approved source donor.
serpy keeps its own identity, credentials, signing, services, and release path.

## Start Here

1. Read [PRODUCT.md](PRODUCT.md).
2. Read [Version 1 stabilization](docs/product/version-1-stabilization.md).
3. Read [ARCHITECTURE.md](ARCHITECTURE.md).
4. Read [DELIVERY_PLAN.md](DELIVERY_PLAN.md).
5. Read [Testing and verification](docs/engineering/testing.md).
6. Read [ACCEPTANCE.md](ACCEPTANCE.md).
7. Read [PROVENANCE.md](PROVENANCE.md) before importing any donor code or assets.
8. Read [AGENTS.md](AGENTS.md) before making changes.

Private beta release procedure: [docs/RELEASING.md](docs/RELEASING.md).

Latest historical private beta:
[SERPy 0.1.0 Beta 1](https://github.com/serpcompany/serpy-clicky-mac-app/releases/tag/v0.1.0-beta.1).

## Current Gate

Status: Version 1 stabilization is tracked by
[Issue #11](https://github.com/serpcompany/serpy-clicky-mac-app/issues/11).
The historical `v0.1.0-beta.1` artifact does not satisfy the current functional
acceptance gate. Public distribution remains separately approval-gated.

## Source-of-Truth References

- [OpenClicky evaluation record](docs/reference/openclicky-evaluation.md)
- Prior clean-room evidence workspace:
  `/Users/devin/dev/repos/clone-keylume-ios-app`
- Recorded OpenClicky findings:
  `https://github.com/devinschumacher/openclicky-internal-releases/issues`

These records are evidence inputs. They are not dependencies of this repo.
