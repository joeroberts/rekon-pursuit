# VD2-07x Save-panel leaf authority — QA re-gate 2

**Date:** 2026-08-01
**Role:** Fresh independent QA/test release re-gate
**Scope:** ADR-005, the leaf-authority plan and task brief, the prior QA
needs-change record, the three-file boundary, current test/worker interfaces,
Xcode target membership, and result-command feasibility. No source or test
code was changed by this review.

## Verdict: ACCEPT

The four corrections required by the prior QA re-gate are now complete and
consistent between the controlling plan and task brief. The slice may proceed
to the remaining independent release gates; this decision is not
post-implementation verification and does not replace the mandatory signed
owner-native smoke.

## Evidence reviewed

### Canonical selected-leaf RED

- ADR-005, plan step 1, and brief test procedure all specify the same digest:
  SHA-256 of the UTF-8 domain separator
  `RekonPursuit/export/leaf-destination/v2\0` followed by the lexically
  standardized, NFC selected-leaf path. The filename is included by that path
  and separately bound by the confirmation fingerprint; no document retains a
  parent identity or v1 parent digest.
- The plan prints an executable test using
  `makeProtectedExportFeedbackFixture(faultMode: .none,
  destinationName: "Cafe\u{301}.rekonexport")`, imports `CryptoKit`, builds
  the expected digest with `SHA256`, checks the display filename, and verifies
  review has not created an output. The brief requires the identical fixture,
  decomposed Unicode leaf, and calculation.
- Current source confirms this is behaviorally RED before the worker change:
  review still derives the v1 parent identity digest. Current fixture signature
  requires `faultMode` and accepts `destinationName`, so the stated RED is
  executable rather than a compile-time fixture error. The current core test
  file does not yet import CryptoKit; the plan explicitly adds it before that
  test.

### Immutable tamper coverage

- Both artifacts print the narrow test-local `reconstructReview` helper with
  optional locator, digest, and fingerprint substitutions while retaining the
  captured source revision. It is explicitly added only after removal of the
  production `parentIdentity` member and does not make review state mutable or
  persisted.
- Both require three distinct behavioral tests: changed leaf locator with the
  reviewed digest/fingerprint retained, changed digest only, and changed
  fingerprint only. Each must reject as `destinationChanged` before output and
  without verified event/activity evidence.

### Post-verification evidence ordering

- The plan and brief both require the worker-local immutable default-`none`
  `beforeEvidenceCommit` fault. It is constrained to run after same-FD
  read-back and successful `ProtectedExportService.verify`, immediately before
  the evidence transaction, with no production selection, persistence,
  environment input, Store injection, or ViewModel API.
- Its required test independently verifies the output package, expects
  `outputMayRemainAfterFailure`, and asserts zero `protected_export_events`
  rows and zero `protected_export_verified` activities. This is distinct from
  the post-descriptor output failure test.

### Three independently inspectable result bundles

Both artifacts now print complete `xcodebuild test` commands, each configured
for Debug/macOS arm64 with the actual target selector
`RekonPursuitTests/ProtectedExportTests`, plus the three protected-export
ViewModel selectors that will exist after the permitted test-island rename:

| Phase | DerivedData | Result bundle | Required inspection |
| --- | --- | --- | --- |
| RED | `/private/tmp/rekon-vd207x-save-panel-leaf-red-dd` | `/private/tmp/rekon-vd207x-save-panel-leaf-red.xcresult` | `xcresulttool` summary and tests |
| GREEN | `/private/tmp/rekon-vd207x-save-panel-leaf-green-dd` | `/private/tmp/rekon-vd207x-save-panel-leaf-green.xcresult` | `xcresulttool` summary and tests |
| Regression | `/private/tmp/rekon-vd207x-save-panel-leaf-regression-dd` | `/private/tmp/rekon-vd207x-save-panel-leaf-regression.xcresult` | `xcresulttool` summary and tests |

The required RED failure is limited to the absent canonical leaf-digest
behavior; all selected tests must execute once with zero skips/expected
failures. GREEN and regression must pass with the same zero-skip condition.
`git diff --check` is retained as an additional GREEN/regression check, not a
result-bundle substitute.

## Boundary and command checks

- `xcodebuild -list -project RekonPursuit.xcodeproj` reports
  `RekonPursuitTests` as the unit-test target. The project sources
  `RekonPursuitCoreTests/ProtectedExportTests.swift` in that target, so the
  command selectors are correct.
- The current `WorkspaceViewModelTests.swift` diff has no hunk in the allowed
  preimage island (current lines 692–863); the first later dirty hunk begins at
  original line 1048. The brief keeps all model-test edits to the clean
  protected-export feedback island and immediately following helpers.
- `git diff --check` completed with exit code 0 during this review.
- The current worker still contains the parent-descriptor implementation and
  parent fault modes. That is the expected pre-implementation state; the plan
  and brief narrowly require their removal only from the worker, core tests,
  and clean model-test island.

## Remaining release and acceptance gates

Before implementation, obtain fresh Architect, Security/privacy, TPM, and
Delivery Manager release decisions. After implementation, independently inspect
the actual RED, GREEN, and regression bundles and run the mandatory signed
Debug owner-native Save-panel smoke. Do not mark the dashboard task complete
until that owner-native confirmation is recorded.
