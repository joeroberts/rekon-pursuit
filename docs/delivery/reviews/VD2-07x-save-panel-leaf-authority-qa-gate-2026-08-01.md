# VD2-07x save-panel leaf authority — QA gate

**Date:** 2026-08-01
**Role:** Independent pre-implementation QA/test gate
**Scope:** ADR-005, implementation plan, task brief, current worker, project
test membership, and protected-export tests. No production or test source was
changed.

## Verdict: NEEDS CHANGE

The intended security contract and the signed owner-native acceptance are
sound, but the brief does not yet define an executable RED discriminator for
leaf authority, and its controlling plan names a nonexistent test target. The
following amendments are required before implementation is released.

## Evidence reviewed

- ADR-005 requires the selected leaf URL as the only external-write authority,
  no ancestor inspection or parent identity binding, exclusive no-follow leaf
  creation, truthful pre-/post-descriptor failures, and verified-only evidence.
- The current worker still calls `openParent`, performs `fstatat`, binds
  `parentIdentity`, and creates via `openat`; see
  `RekonPursuitCore/Workspace/ProtectedExportWorker.swift:66-97` and
  `:152-225`.
- The project has the test target `RekonPursuitTests`; it has no
  `RekonPursuitCoreTests` target. `ProtectedExportTests.swift`, although stored
  under `RekonPursuitCoreTests/`, is compiled into `RekonPursuitTests`.
- The existing real-store success test passed once using
  `RekonPursuitTests/ProtectedExportTests/testProtectedExportIsEncryptedAndVerifiableWithRecoveryKey`
  (zero failures) before this review. It proves the current parent-authorized
  worker can create a temporary leaf, so a new ordinary temporary-leaf success
  test would also pass before the repair.
- Current tests explicitly assert the obsolete parent contract:
  `testReviewBindsDestinationParentIdentity`,
  `testParentOpenUnavailableWithValidSuffixUsesDestinationUnavailableWithoutReview`,
  and
  `testParentInspectionUnavailableWithValidSuffixUsesDestinationUnavailableWithoutReview`.
  They cannot remain in the class-wide focused selector after parent access is
  removed.

## Required amendments

1. **Make RED prove the leaf-binding algorithm, not simulated Save-panel
   authority.** Replace the old parent-identity review test with an executable
   real-store test that uses a fresh decomposed-Unicode `.rekonexport` name,
   computes the ADR-005 value independently, and asserts:

   ```swift
   let canonicalLeaf = destination.standardizedFileURL.path
       .precomposedStringWithCanonicalMapping
   var input = Data("RekonPursuit/export/leaf-destination/v2\\0".utf8)
   input.append(contentsOf: canonicalLeaf.utf8)
   XCTAssertEqual(review.destinationIdentityDigest, Data(SHA256.hash(data: input)))
   XCTAssertEqual(review.displayFilename, destination.lastPathComponent
       .precomposedStringWithCanonicalMapping)
   ```

   It must also assert the leaf does not exist before confirm. This test is
   assertion-RED on the current parent-identity/v1 implementation while
   remaining a normal real-store behavioral test. Do not describe a temporary
   directory or an injected permission failure as proof of macOS
   `NSSavePanel` authorization. The mandatory signed owner-native smoke is the
   only acceptance that proves that operating-system grant.

2. **Replace, rather than leave failing, obsolete parent tests.** Remove or
   rewrite all three parent-authority tests above in the same test-file change;
   after the repair there must be no parent-open, parent-inspection, parent
   identity, `fstatat`, or `openat` expectation or legacy parent-fault mode.
   Retain only a worker-local, immutable default-`.none` seam for the direct
   leaf pre-descriptor and post-descriptor fault tests. The plan and brief must
   name the replacement test inventory, including the canonical digest RED
   test, ordinary verified leaf success, invalid name, existing regular leaf,
   terminal symlink, after-review sentinel collision, source change, each
   review-tamper variant, direct-leaf pre-descriptor failure, post-descriptor
   failure, and evidence ordering.

3. **Exercise every confirmation binding separately and preserve test
   immutability.** The task brief's single altered-review bullet is
   insufficient. Add independent cases for (a) changed leaf locator with the
   reviewed digest/fingerprint retained, (b) changed digest only, and (c)
   changed fingerprint only. Each must return `destinationChanged` before any
   output or verified event/activity. The source-change case must likewise
   assert absent output and zero filtered verified activity/export rows, not
   only the error. Define a narrow, immutable test-only review reconstruction
   approach before RED so the assertions do not need to change when
   `parentIdentity` is removed; it must not make a production review mutable,
   persist test state, or synthesize a parent identity.

4. **Strengthen collision and failure evidence.** The regular-leaf and
   terminal-symlink tests must preserve sentinel bytes, assert the symlink
   remains a symlink, and record no verified evidence. The after-review
   sentinel collision must first obtain a real review, then assert
   `destinationExists`, byte-for-byte preservation, and no evidence. The
   direct-leaf pre-descriptor fault must assert the existing unavailable
   message, no output, and zero verified rows/activity. The post-descriptor
   fault must assert `outputMayRemainAfterFailure`, an extant output, zero
   verified rows/activity, and never the pre-descriptor error.

5. **Prove evidence ordering beyond immediate post-create failure.** Add a
   separate immutable test fault, scaffolded as ignored/default-`.none` before
   RED and placed in GREEN immediately after final-FD read-back and successful
   cryptographic verification but before the evidence transaction. Its test
   must verify the retained output independently with
   `ProtectedExportService.verify`, then assert the conservative failure and
   zero verified export/activity rows. This is required to demonstrate that
   evidence cannot precede read-back and verification; the current
   `afterOutputCreation` fault alone occurs too early to prove that ordering.

6. **Reconcile the commands and preserve distinct evidence.** Amend every
   plan command that says `RekonPursuitCoreTests/ProtectedExportTests` to the
   real identifier:

   ```bash
   -only-testing:RekonPursuitTests/ProtectedExportTests
   ```

   The task brief's worker/test-only scope prohibits the plan's optional
   `WorkspaceViewModelTests` selector and change; remove both from this slice.
   The RED, GREEN, and regression invocations must each use a fresh,
   non-existing `/private/tmp/rekon-vd207x-save-panel-leaf-{red,green,regression}`
   DerivedData path and matching distinct `.xcresult` path. After each run,
   retain and inspect both:

   ```bash
   xcrun xcresulttool get test-results summary --path <bundle>
   xcrun xcresulttool get test-results tests --path <bundle>
   ```

   The RED bundle must show every new selected test executing once with zero
   skips/expected failures and failing only the canonical leaf-authority
   behavior. GREEN and regression must show the selected protected-export tests
   executing once and passing with zero skips/expected failures. Run `git diff
   --check` only after GREEN/regression; it does not replace result-bundle
   inspection.

7. **Tighten signed owner-native acceptance.** Keep the stated actual
   `NSSavePanel` flow and redacted-evidence rules, and add an effective signed
   entitlement check to the build evidence: inspect the built app's effective
   entitlements and record only that app sandboxing and
   `com.apple.security.files.user-selected.read-write` are true. The owner must
   use a fresh workspace and a newly created Documents child folder, choose a
   fresh leaf, reach filename-only review without the former folder error,
   confirm exactly one nonempty output, and receive filename-safe success. No
   key, path, export, database, or entitlement dump is retained. This smoke
   must be accepted separately from unit-test GREEN and must make no
   parent-continuity claim.

## Release condition

Accept only after the plan and task brief agree on the two-file scope, the real
`RekonPursuitTests` selector, the assertion-RED method, full error/evidence
matrix, separate result bundles, and signed owner-native acceptance above.
