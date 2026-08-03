# VD2-07x Save-panel leaf authority — QA re-gate

**Date:** 2026-08-01
**Role:** Fresh independent QA/test re-gate
**Scope:** ADR-005, the current leaf-authority plan and task brief, the prior
QA and Security/privacy gates, the reconciled three-file test boundary, current
source/tests, Xcode project membership, and command feasibility. No production
or test source was changed by this review.

## Verdict: NEEDS CHANGE

The selected-leaf contract, the reconciled clean test island, and the actual
unit-test target are correct. Do not release implementation yet: the controlling
plan and brief do not jointly provide an executable canonical-leaf RED, the
full collision/tamper/evidence-order matrix, and three separately inspectable
result bundles.

## Confirmed boundary and target membership

- ADR-005 correctly requires transient authority for the exact Save-panel leaf,
  no parent inspection/binding, exclusive no-follow creation, and verified-only
  evidence after read-back verification.
- The scope reconciliation is sound: exactly three authored paths are allowed:
  `ProtectedExportWorker.swift`, `ProtectedExportTests.swift`, and the clean
  `WorkspaceViewModelTests.swift` feedback island (current lines 706–860).
  `git diff -U0 -- RekonPursuitTests/WorkspaceViewModelTests.swift` has no
  hunk in that island; its dirty hunks begin elsewhere. The two obsolete model
  review tests and the pre-descriptor model test may therefore be retired or
  reasserted only in that island. Production ViewModel source and every other
  dirty model-test hunk remain out of scope.
- `xcodebuild -list -project RekonPursuit.xcodeproj` reports the unit-test
  target as `RekonPursuitTests`, not `RekonPursuitCoreTests`. The project file
  puts the source file stored at `RekonPursuitCoreTests/ProtectedExportTests.swift`
  in that `RekonPursuitTests` target. Consequently the canonical-leaf RED's
  actual selector must be, and the current commands correctly use,
  `-only-testing:RekonPursuitTests/ProtectedExportTests`.
- The frozen implementation and tests still contain `parentIdentity`,
  `openParent`, `fstatat`, `openat`, the two parent fault modes, and their
  parent expectations. The brief/plan correctly require their removal through
  the three authorized paths, with the model-test portion confined to the
  clean island. This is a required implementation result, not evidence that
  the pre-implementation worktree is already repaired.

## Required test matrix

| Contract | Current disposition |
| --- | --- |
| Canonical leaf-digest RED | The class selector is correct, but the plan's shown test is not executable against the current fixture: it omits required `faultMode: .none`, uses a non-decomposed ASCII name, and uses `SHA256` without specifying `import CryptoKit`. |
| Regular-leaf collision, terminal symlink, and post-review sentinel collision | Required by both artifacts with byte preservation and no verified evidence. |
| Review tamper | Required separately for changed locator with retained digest/fingerprint, changed digest only, and changed fingerprint only; each must reject before output. Neither artifact defines the narrow immutable test reconstruction needed before RED, so the tests would be coupled to removal of `parentIdentity`. |
| Source revision | Required to return `sourceChanged` before output and without verified evidence. |
| Pre-descriptor direct-leaf failure | Required to retain review, produce unavailable-destination feedback, and create neither output nor evidence. |
| Post-descriptor failure | Required to report only the conservative may-remain state, leave any output for user handling, and add no verified evidence. |
| Evidence ordering | The task brief requires an immutable post-verification/pre-evidence fault with independently verified output and zero event/activity rows. The plan only describes success after read-back; it omits this fault and its executable assertion. |

The canonical RED must be amended to use a fresh decomposed-Unicode
`.rekonexport` leaf, independently calculate the `RekonPursuit/export/leaf-destination/v2\\0`
digest, pass `faultMode: .none` (or explicitly add that local helper default),
and import CryptoKit. It must compile and fail only the absent leaf-authority
assertion before worker behavior changes; it must not fail due to fixture setup,
target resolution, compilation, signing, a skip, or an expected failure.

## Result-bundle and smoke evidence

The plan has an explicit RED command and inspections and an explicit regression
command and inspections, but it only says to rerun the RED command with
`leaf-green` paths; it does not print the GREEN bundle path or its two
`xcresulttool` inspections. Conversely, the brief prints RED and GREEN
commands/inspections but contains no regression command or regression-bundle
inspection. The artifacts therefore do not jointly require the requested three
distinct, non-overwritable bundles:

1. `...-leaf-red.xcresult` — every selected new test runs once, with zero
   skips/expected failures; only the canonical leaf-authority assertion is RED.
2. `...-leaf-green.xcresult` — the same focused suite runs once and passes,
   with zero skips/expected failures.
3. `...-leaf-regression.xcresult` — the stated focused regression selection
   runs once and passes, with zero skips/expected failures.

Both controlling artifacts must print all three complete commands, each with a
fresh matching DerivedData path, and after each command require both
`xcrun xcresulttool get test-results summary --path <bundle>` and
`xcrun xcresulttool get test-results tests --path <bundle>`. `git diff --check`
remains an additional GREEN/regression check, not a substitute for bundle
inspection.

The signed Debug build, strict signature verification, effective-entitlement
readback, and redacted owner run through the actual `NSSavePanel` are correctly
defined as a separate mandatory native smoke. It is not a unit-test result and
must not be used to reinterpret the RED/GREEN bundles. Its accepted evidence is
only the redacted assertion of App Sandbox plus the existing user-selected
read/write entitlement, and owner confirmation that a fresh Documents-child
leaf reaches filename-only review and produces one nonempty export without the
former folder rejection.

## Release corrections

1. Make the canonical-digest test executable exactly as above, while retaining
   the correct `RekonPursuitTests/ProtectedExportTests` selector.
2. Define a narrow test-local immutable reconstruction helper for the three
   review-tamper variants, so their behavioral assertions survive removal of
   `parentIdentity` without making a production review mutable or persisting
   test state.
3. Add the post-verification/pre-evidence immutable default-`none` fault and
   its independent package-verification/no-evidence test to the plan; keep it
   worker-local with no production selection, persistence, environment input,
   Store injection, or ViewModel API.
4. Reconcile plan and brief on three explicit RED, GREEN, and regression
   commands and both `xcresulttool` views for every distinct bundle.
5. Retain the reconciled three-file scope. At implementation, remove all stale
   parent modes/tests/expectations only from the authorized worker/core-test
   paths and the clean 706–860 model-test island; do not touch any other dirty
   ViewModel-test hunk or production ViewModel source.

Reissue the independent QA gate after those documentation corrections. The
signed owner-native smoke remains a later post-GREEN acceptance requirement.
