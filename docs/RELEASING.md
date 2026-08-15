# Private beta releases

SERPy uses Semantic Versioning prerelease tags. The first meaningful internal
product slice is `v0.1.0-beta.1`: the app marketing version remains `0.1.0`,
the Xcode build number increases monotonically, and `beta.1` identifies the
first prerelease of that version.

Release DMGs are not committed to Git. An annotated Git tag identifies the
exact source, while the notarized DMG, SHA-256 file, and manifest are attached
to a private GitHub prerelease.

## Trusted-Mac pipeline

Run releases on the registered Mac that holds the approved Developer ID
Application identity and configured `asc` notarization authentication:

```bash
scripts/release-private-beta.sh \
  v0.1.0-beta.1 \
  docs/releases/v0.1.0-beta.1.md
```

The command refuses to release unless:

- the branch is `main` with a clean working tree;
- local `main` exactly matches private `origin/main`;
- the tag and GitHub release do not already exist;
- the tag version matches the built app version;
- Swift tests and the Developer ID Release build pass;
- Apple notarization is accepted and stapled;
- Gatekeeper accepts the DMG and mounted app;
- the manifest commit and checksum match the exact artifacts.

It then pushes an annotated tag, creates a draft GitHub prerelease, uploads the
three artifacts, verifies the asset count, and publishes the prerelease.

## Hosted automation boundary

GitHub-hosted signing is intentionally not configured. It would require an
approved transfer of the Developer ID certificate/private key and App Store
Connect authentication into GitHub Actions secrets. Do not add those secrets
or export signing material without a separate owner decision and threat-model
review.
