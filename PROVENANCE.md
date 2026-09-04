# Provenance and donor policy

## Approved references

| Reference | Role |
| --- | --- |
| Installed `/Applications/HeyClicky.app` | Version 1 UX and behavior oracle |
| `https://github.com/farzaa/clicky` at `a80fa80721a8aebe51a170a7780705024ebc6e46` | Approved MIT source donor for Dictation/Guide stabilization |
| OpenClicky | Secondary behavioral/source reference when the approved donor lacks the required behavior |
| Superwhisper public behavior | Dictation outcome benchmark only |

The owner approved reuse of the pinned historical Clicky source for Version 1.
An implementation agent does not need another permission decision before using
code from that exact revision.

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
