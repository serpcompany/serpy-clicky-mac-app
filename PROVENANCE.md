# Provenance and donor policy

## Approved references

| Reference | Role |
| --- | --- |
| Installed `/Applications/HeyClicky.app`, the owner's Issue #7 recording, and HeyClicky's public product material | Sole Version 1 Guide UX and behavior oracle |
| `https://github.com/farzaa/clicky` at `a80fa80721a8aebe51a170a7780705024ebc6e46` | Approved MIT source donor from the same HeyClicky product family |
| `https://github.com/FrigadeHQ/yap` at `5f06bb1aa889abaa064b09a9bf33aff984dc1583` | Approved primary MIT donor for the macOS 26 Dictation pipeline |
| `https://github.com/Starmel/OpenSuperWhisper` at `bef6bc0421d0c010e8f2fb4288c0d74978c8b964` | Approved secondary MIT donor for recording lifecycle, stop-tail, and pasteboard behavior |
| `https://github.com/human37/open-wispr` at `7ab4e62e8f182f3ecc2116e1094a1eb4416a248f` | Approved secondary MIT donor for lifecycle and insertion tests |
| Superwhisper public behavior | Dictation outcome benchmark only |

The owner approved source-first reuse of these pinned donor revisions for
Version 1. An implementation agent does not need another permission decision
before using code from those exact revisions.

Guide work must not use a second assistant product to fill perceived gaps.
HeyClicky is the only Guide product reference. Frigade Assistant is explicitly
excluded from Guide research and implementation; Yap's approval is limited to
Dictation code.

## Required import record

Reuse remains traceable rather than ambiguous. Before committing imported or
derived code, add or update one record under `docs/imports/` containing:

- upstream repository and exact commit;
- source path and adopted symbols or ranges;
- MIT license/notice attribution;
- dependencies retained or removed;
- serpy-specific modifications;
- tests protecting the adopted behavior; and
- upstream product identity, assets, credentials, signing, services, worker
  configuration, update feeds, and release destinations removed.

This record documents an approved import; it is not a second approval gate.

## Separation boundary

The installed HeyClicky app may be observed through normal UI and accessibility
surfaces. The pinned public repository may be read, copied, and modified under
its MIT license. Later private HeyClicky implementation, credentials, services,
and unavailable source remain outside the donor boundary.

The shipped product uses the lowercase **serpy** name and owner-controlled
branding. Keep the existing bundle identifier, signing identity, Keychain
service, preferences domain, and release destination during stabilization.
Never copy upstream secrets, Team IDs, bundle IDs, signing assets, Sparkle keys,
appcasts, hosted endpoints, or user/account data.

MIT code permission does not automatically license third-party trademarks,
marketing copy, icons, artwork, or sounds. Use serpy-owned or system assets
unless a specific asset is covered and recorded.

## Historical records

Existing build reports and import notes describe what earlier branches did.
Statements such as “no donor code was imported” remain true for those historical
builds, but they do not restrict new Version 1 work. This file and
`docs/product/version-1-stabilization.md` control current implementation.
