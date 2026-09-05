# Build 45: diagnostics transport proven, privacy gate failed

2026-09-05. Not accepted for continued use.

- Source `f35fea6342c00df3127a560361cbc7a4a8242683`.
- Signed/notarized/stapled DMG passed the release verifier.
- Installed executable SHA-256:
  `e4813c073a780545daa78514c80f2d7d29d08ed372b4f031100bb333ca11d732`.
- A real Guide start with no valid external target produced a visible capture
  failure before listening and Sentry issue `SERPY-CLICKY-MAC-APP-2`.
- Retrieved event `3da56746f1a34cefbf5fc958a240346d` identifies `internal-test`,
  build 45, fixed code `guide.failure.unclassified`, stage `capture`, provider
  `none`. No owner-mediated diagnostic copy was required.
- Stored-event inspection found nonempty IP/geo fields and trace context,
  despite client scrubbing. Actual values are deliberately not recorded here.
  Client unit tests are insufficient to prove server-side stored privacy.
- Build 45 was immediately quit and moved to
  `/private/tmp/SERPy-build45-privacy-rejected.app`. The preserved reporting-off
  build 44 was restored to `/Applications/SERPy.app`. No event deletion or
  project-setting mutation has been performed.
- Next gate: prevent server IP/geo enrichment and post-scrub trace context,
  then repeat installed capture-failure transport and inspect the stored event.
  Do not enable continuing reporting before that verification passes.

Separately, the attempted source push was rejected non-fast-forward. The remote
branch was fetched and contains newer evidence-contract work through `4497032`.
Local changes were not forced over it; integration remains pending.
