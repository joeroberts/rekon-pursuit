# VD2-05 — Core-suite repair-plan Task 3 whole-suite proof release

**Date:** 2026-07-31  
**Role:** Fresh independent Delivery Manager  
**Decision:** **COMPLETE — repair-plan Task 3 accepted; parent VD2-05 Task 2
accepted.**

## Final acceptance

The released no-edit proof is complete. Fresh independent Code Review, QA,
Architecture, Security/privacy, and final TPM gates all accepted the same
immutable source and complete signed results with no findings:

| Gate | Evidence | Decision |
| --- | --- | --- |
| Code Review | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-3-whole-suite-proof-code-review.md` | ACCEPT; exact Core 114/114 and ViewModel 91/91 inventories, signatures, hashes, and source boundary verified. |
| QA | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-3-whole-suite-proof-post-implementation-qa.md` | ACCEPT; independent isolated signed rebuild reproduced Core 114/114 and ViewModel 91/91 with no failures, skips, or expected failures. |
| Architecture | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-3-whole-suite-proof-post-implementation-architecture.md` | ACCEPT; transaction architecture and ADR remain conformant; no architecture change. |
| Security/privacy | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-3-whole-suite-proof-post-implementation-security.md` | ACCEPT; fixture, persistence, migration, recovery, signing, and privacy boundaries remain intact. |
| Final TPM | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-3-whole-suite-proof-final-tpm-gate.md` | ACCEPT; repair Task 3 may close and parent VD2-05 Task 2 may be accepted. |

Delivery therefore records repair-plan Task 3 complete and accepts parent
VD2-05 Task 2, “Transactional Core + view-model result.” This does not accept
VD2-05 as a whole or any unrelated dirty-worktree content.

## Dependency decision

Slice B is complete. All required independent post-gates accept the same final
test source and evidence with no findings:

| Gate | Evidence | Decision |
| --- | --- | --- |
| Final Core Code Review | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-2-slice-b-final-core-code-review.md` | ACCEPT; specification-compliant one-file test repair. |
| QA | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-2-slice-b-post-implementation-qa.md` | ACCEPT; independently reproduced signed 14/14 and all mutation evidence. |
| Architecture | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-2-slice-b-post-implementation-architecture.md` | ACCEPT; exact fixture architecture, unchanged runtime, no ADR. |
| Security/privacy | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-2-slice-b-post-implementation-security.md` | ACCEPT; encrypted fixture/recovery/privacy boundaries and mutation restoration verified. |
| TPM | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-2-slice-b-post-implementation-tpm-gate.md` | ACCEPT; Slice B may close and only whole-suite proof is dependency-safe. |

The immutable whole-suite proof source baseline is:

```text
83d61ea4769da4c44c8466b5af76415f7e9ecebf974295ba036a424921dc2162  RekonPursuitCoreTests/WorkspaceStoreTests.swift
```

Preserve the original 108-test RED, all Slice A RED/GREEN evidence, the
missing-builder RED, all six mutation results, and both accepted signed 14/14
Slice B GREEN bundles.

## Exact released evidence work

Release only Task 3, “Whole-suite proof and release hold,” from
`docs/superpowers/plans/2026-07-31-vd205-core-suite-evidence-repair.md`.
This is evidence execution and makes no implementation change.

Run the complete signed Core selector:

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests \
  -derivedDataPath /tmp/rekon-vd205-core-suite-full-core-dd \
  -resultBundlePath /tmp/rekon-vd205-core-suite-full-core.xcresult
```

Run the complete signed ViewModel selector separately:

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests \
  -derivedDataPath /tmp/rekon-vd205-core-suite-full-vm-dd \
  -resultBundlePath /tmp/rekon-vd205-core-suite-full-vm.xcresult
```

For both bundles:

- inspect finalized `xcresulttool` summaries and detailed test records;
- require the complete selected suite to be enumerated, with every executed
  test passed and zero failed, skipped, or expected failures;
- reject a missing selector, build error, early termination, or non-pass;
- strictly verify and inspect identity for the generated Debug app, host
  executable, and nested XCTest bundle;
- record hashes for the unchanged test source, app executable, XCTest
  executable, and result `Info.plist`.

## Boundary and post-gates

Re-run the accepted-baseline comparison, implementation-source path review,
obsolete-helper scan, forbidden builder/oracle call scan, and
`git diff --check`. Reject any source drift from the immutable hash or any
change outside the already accepted
`RekonPursuitCoreTests/WorkspaceStoreTests.swift` repair.

Submit both complete signed results and boundary evidence to a fresh separate
Code Reviewer and independent QA verifier, then Architecture, TPM,
Security/privacy, and Delivery. Delivery alone may subsequently decide parent
VD2-05 Task 2 acceptance.

## Explicit non-authorizations and holds

The proof runner may not edit production, tests, schema, migrations, recovery,
UI, Board, project/signing, entitlements, dashboard, roadmap, ledger, delivery
status, or commits.

This proof is not the original VD2-05 Task 3/Board interaction. The original
Board task is governed by its separate content-baselined Delivery release.
Card relocation is not yet delivered. Owner handoff, status advancement, final
VD2-05 acceptance, and VD2-06–08 remain blocked.
