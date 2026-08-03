# VD2-07x — Save-panel leaf-authority task brief

**Status:** DRAFT — planning only. This brief releases no implementation until
the independent pre-implementation gates below have accepted it.

## Single bounded TDD slice

Replace the protected-export worker's unsupported parent-directory authority
assumption with authority for the exact transient `.rekonexport` leaf returned
by `NSSavePanel`, while retaining the existing verified-write security
contract.

### Signed root cause

In a signed sandboxed macOS build, a native `NSSavePanel` grant authorizes the
selected new file URL. It does **not** grant recursive authority for that
file's parent directory. The frozen worker nevertheless opens and binds that
parent by device/inode, probes it with `fstatat`, and creates the leaf with
`openat`. A normal native Save-panel selection can therefore be rejected before
review even though macOS has granted the intended least-privilege authority for
the selected leaf. The repair removes that mismatch; it does not claim
parent-directory continuity.

## Controlling artifacts

- `docs/architecture/adr/ADR-005-save-panel-leaf-export-authority.md`
- `docs/superpowers/plans/2026-08-01-vd207x-save-panel-leaf-authority.md`
- `docs/delivery/task-briefs/VD2-07x-protected-export-destination-feedback.md`

## Exact source boundary

| Path | Permitted change |
| --- | --- |
| `RekonPursuitCore/Workspace/ProtectedExportWorker.swift` | Review/confirmation leaf binding, direct-leaf create/error handling, and only the local deterministic fault support required by the focused tests. |
| `RekonPursuitCoreTests/ProtectedExportTests.swift` | Focused real-store protected-export tests and their local fixture helpers. |
| `RekonPursuitTests/WorkspaceViewModelTests.swift` | Only the clean existing protected-export feedback island at current lines 706–767 and its immediately following helpers at current lines 770–860: delete the two obsolete parent-authority review tests, rename/reassert the pre-descriptor confirm fault as direct-selected-leaf unavailable feedback, and retain the model's existing exact public error assertions. No other hunk is authorized. |

`WorkspaceStore` and the existing ViewModel mapping are inspection-only: their
public seams and owner-facing copy must remain compatible. The permitted model
test island is clean in the starting worktree; the implementer must record its
exact pre-task line context and stage only that isolated hunk. If it overlaps
another edit before implementation, stop and obtain a new integration plan.

The following are expressly out of scope: Settings visuals or accessibility;
the Save-panel visual workflow; entitlement or signing changes; bookmarks or
any other persistent security-scope material; persistence/schema/activity
schema changes; dashboard state or delivery-dashboard presentation; project
files; dependencies; and all existing dirty ViewModel test hunks. No new
preference, path persistence, raw-path activity/audit evidence, or recovery
material is authorized.

## Required behavior and constraints

1. Preserve the one-step native Save panel, `.rekonexport` filter, default
   filename, and folder-creation capability. Preserve the existing
   `com.apple.security.files.user-selected.read-write` entitlement exactly;
   this task neither adds an entitlement nor saves a bookmark.
2. At review, validate the NFC final filename and derive an in-memory digest
   from UTF-8 `RekonPursuit/export/leaf-destination/v2\0` followed by the
   lexically standardized, NFC selected-leaf path. That path includes the NFC
   filename; the filename remains separately bound by the confirmation
   fingerprint. Do not resolve, open, stat, bind, or otherwise inspect an
   ancestor. Remove the
   parent descriptor, device/inode identity, `fstatat`, parent identity
   comparison, and `openat` flow from this export path.
3. Bind the existing confirmation fingerprint to export type, fixed category,
   NFC filename, canonical selected-leaf digest, and captured source revision.
   Immediately before staging/final write, recompute the digest and fingerprint
   from the reviewed leaf URL. A mismatch is `destinationChanged`; a changed
   source revision remains `sourceChanged`. Neither condition creates output or
   verified evidence.
4. Create only the selected leaf with `O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW`
   and mode `0600`. Capture `errno` immediately on a failed direct `open`:
   `EEXIST`, including an occupied leaf or terminal symlink, is the existing
   no-overwrite error. Any other direct-leaf failure **before an output
   descriptor exists** is the existing unavailable-destination error. Never
   expose a path, POSIX error, security-scope result, export content, or key.
5. Once an output descriptor exists, any write, `fstat`, `fsync`, descriptor
   read-back, cryptographic verification, or evidence-transaction failure is
   the existing conservative `outputMayRemainAfterFailure` result. Do not
   retry, overwrite, or pathname-delete the selected leaf. Such a failure adds
   no verified export event and no `protected_export_verified` activity.
6. Keep final-FD `fstat`, streaming write, `fsync`, same-FD read-back, and
   encrypted-package verification. Create the one protected-export event and
   one filtered verified activity only after that verification succeeds. The
   selected URL and raw path never enter persisted or activity/audit evidence.

## Test-first implementation procedure

1. Confirm the three allowlisted files are the only proposed authored files.
   If a test seam cannot express the pre-descriptor and post-descriptor
   conditions, add only a worker-local, immutable default-`none` seam with no
   production selection, persistence, environment input, or Store/ViewModel
   injection. Run the current targeted export tests green before adding
   behavior tests. In the allowlisted clean model-test island only, delete the
   stale parent-mode review assertions. Rename and reassert the existing
   pre-descriptor confirm test as a direct-selected-leaf failure: review must
   succeed, confirm must retain the review, and the controlled unavailable
   feedback must appear. Retain the post-descriptor may-remain state assertion.
   Production ViewModel source remains untouched.
2. In `ProtectedExportTests`, add `import CryptoKit` and write executable tests
   against a real temporary,
   enrolled store and generated recovery key. New tests must be assertion RED,
   not compilation errors, skips, expected failures, mocked call counts, chmod
   tricks, sandbox-denial simulations, sleeps, polling, or raw-`errno`
   assertions. Cover each of these separately:

   - a fresh decomposed-Unicode selected leaf—specifically
     `"Cafe\u{301}.rekonexport"` through
     `makeProtectedExportFeedbackFixture(faultMode: .none, destinationName:)`—has a pre-confirmation
     `destinationIdentityDigest` equal to the independently calculated
     `RekonPursuit/export/leaf-destination/v2\0` plus lexically standardized,
     NFC path bytes, displays an NFC filename, and has not created a file;
   - a fresh selected leaf completes review, creates a verifiable encrypted
     export, and records exactly one verified export row and filtered activity;
   - a non-`.rekonexport` final name creates no file or verified evidence;
   - an existing regular leaf and a terminal symlink are not overwritten and
     record no verified evidence;
   - a sentinel leaf created after review returns the no-overwrite result
     without changing its bytes or recording evidence;
   - changed leaf locator with retained digest/fingerprint, changed digest only,
     and changed fingerprint only each reject as `destinationChanged` before
     output; and
   - a source-revision change rejects as `sourceChanged` before output;
   - an injected direct-leaf failure before descriptor assignment returns the
     existing unavailable-destination result with no output/evidence; and
   - an injected failure after descriptor assignment returns the conservative
     may-remain result, leaves no verified evidence, and never reports the
     pre-create error; and
   - an injected `beforeEvidenceCommit` failure after same-FD read-back and
     successful package verification, but before the evidence transaction,
     leaves an independently verifiable output and zero verified event/activity
     rows.

   After removal of the production `parentIdentity` field, define this narrow,
   test-local immutable reconstruction helper and use it for exactly those
   three tamper cases; do not make production review data mutable:

   ```swift
   private func reconstructReview(
       _ review: ProtectedExportReview,
       destinationURL: URL? = nil,
       destinationIdentityDigest: Data? = nil,
       confirmationFingerprint: String? = nil
   ) -> ProtectedExportReview {
       .init(
           destinationURL: destinationURL ?? review.destinationURL,
           sourceRevision: review.sourceRevision,
           destinationIdentityDigest: destinationIdentityDigest ?? review.destinationIdentityDigest,
           confirmationFingerprint: confirmationFingerprint ?? review.confirmationFingerprint
       )
   }
   ```

   The worker-local immutable default-`.none` seam may be scaffolded only for
   the direct-leaf pre-descriptor, post-descriptor, and post-verification/
   pre-evidence faults. It has no production selection, persistence,
   environment input, Store injection, or ViewModel API. A post-verification/
   pre-evidence fault must run after same-FD read-back and successful
   `ProtectedExportService.verify`, but before the evidence transaction. Its
   test independently verifies the output, expects `outputMayRemainAfterFailure`,
   and asserts zero `protected_export_events` rows and zero
   `protected_export_verified` activities.
3. Run the new focused suite as RED before changing worker behavior. Preserve a
   dedicated result bundle and inspect its resolved test list and summary. RED
   is valid only when every new selector executes once, with zero skips and
   zero expected failures, and fails solely on the absent leaf-authority
   behavior—not project configuration, compilation, signing, fixture setup, or
   an unrelated test.

   ```bash
   xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
     -configuration Debug -destination 'platform=macOS,arch=arm64' \
     -only-testing:RekonPursuitTests/ProtectedExportTests \
     -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportInvalidFilenameUsesExactCorrectionMessage \
     -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportUnavailableSelectedLeafConfirmUsesExactCorrectionMessage \
     -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportPostCreateFailureRetainsMayRemainFeedback \
     -derivedDataPath /private/tmp/rekon-vd207x-save-panel-leaf-red-dd \
     -resultBundlePath /private/tmp/rekon-vd207x-save-panel-leaf-red.xcresult
   ```

   ```bash
   xcrun xcresulttool get test-results summary --path /private/tmp/rekon-vd207x-save-panel-leaf-red.xcresult
   xcrun xcresulttool get test-results tests --path /private/tmp/rekon-vd207x-save-panel-leaf-red.xcresult
   ```

4. Implement the smallest three-path GREEN change. Use the exact selected
   leaf path for the canonical digest and exclusive final creation; do not
   broaden access to the parent. Retain the current temporary app-owned
   encrypted package, final descriptor validation, streaming, fsync, same-FD
   read-back, cryptographic verification, and verified-only evidence ordering.
   Do not change UI, persistence, entitlement, signing, bookmarks, or
   ViewModel source to make the suite pass. Remove every obsolete parent fault,
   parent test, and parent expectation in the three authorized paths; stage no
   other ViewModel-test hunk.
5. Run the same selector set as a fresh GREEN invocation with a distinct result
   bundle, inspect its resolved list and summary, and require every selected
   test to pass once with zero skips/expected failures. Then run `git diff
   --check`. Keep the RED and GREEN bundles separate; never overwrite, relabel,
   or substitute one for the other.

   ```bash
   xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
     -configuration Debug -destination 'platform=macOS,arch=arm64' \
     -only-testing:RekonPursuitTests/ProtectedExportTests \
     -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportInvalidFilenameUsesExactCorrectionMessage \
     -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportUnavailableSelectedLeafConfirmUsesExactCorrectionMessage \
     -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportPostCreateFailureRetainsMayRemainFeedback \
     -derivedDataPath /private/tmp/rekon-vd207x-save-panel-leaf-green-dd \
     -resultBundlePath /private/tmp/rekon-vd207x-save-panel-leaf-green.xcresult
   git diff --check
   xcrun xcresulttool get test-results summary --path /private/tmp/rekon-vd207x-save-panel-leaf-green.xcresult
   xcrun xcresulttool get test-results tests --path /private/tmp/rekon-vd207x-save-panel-leaf-green.xcresult
   ```

6. Run the same selector set a third time as a separate regression invocation;
   it has its own DerivedData and result bundle and must be inspected in both
   views before `git diff --check`:

   ```bash
   xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
     -configuration Debug -destination 'platform=macOS,arch=arm64' \
     -only-testing:RekonPursuitTests/ProtectedExportTests \
     -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportInvalidFilenameUsesExactCorrectionMessage \
     -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportUnavailableSelectedLeafConfirmUsesExactCorrectionMessage \
     -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportPostCreateFailureRetainsMayRemainFeedback \
     -derivedDataPath /private/tmp/rekon-vd207x-save-panel-leaf-regression-dd \
     -resultBundlePath /private/tmp/rekon-vd207x-save-panel-leaf-regression.xcresult
   xcrun xcresulttool get test-results summary --path /private/tmp/rekon-vd207x-save-panel-leaf-regression.xcresult
   xcrun xcresulttool get test-results tests --path /private/tmp/rekon-vd207x-save-panel-leaf-regression.xcresult
   git diff --check
   ```

## Signed owner-native smoke (mandatory)

After GREEN, build and verify the signed Debug application:

```bash
xcodebuild build -project RekonPursuit.xcodeproj -scheme RekonPursuit \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /private/tmp/rekon-vd207x-save-panel-leaf-owner-dd
codesign --verify --deep --strict \
  /private/tmp/rekon-vd207x-save-panel-leaf-owner-dd/Build/Products/Debug/RekonPursuit.app
codesign -d --entitlements :- \
  /private/tmp/rekon-vd207x-save-panel-leaf-owner-dd/Build/Products/Debug/RekonPursuit.app 2>&1
```

The signed-app owner, using a fresh separate local workspace, creates a fresh
Documents child folder in the actual `NSSavePanel`, chooses a new leaf, reviews
it, and confirms it. The review must display the filename and must not show the
former folder-unavailable rejection; confirmation must create one nonempty
export and show only the existing filename-safe success feedback. The owner
uses a recovery key never entered in chat, logs, or evidence. No screenshot or
record may include a recovery key, a folder/leaf path, export contents, or a
database. Inspect the entitlement output only to record the redacted assertion
that App Sandbox and the existing `user-selected.read-write` authority are
present, with no task-related entitlement addition. Do not retain the raw
entitlement output; record only redacted completion evidence and the
build/signature outcome.

## Release and post-implementation gates

Before implementation, fresh independent Architect, TPM, QA/test,
Security/privacy, and Delivery Manager gates must release this single slice.
The implementer is a fresh agent and cannot review or verify the work.

After implementation, all of the following gates are required, in order:

1. **Independent code review:** checks the three-path boundary, direct-leaf
   authority, flag/mode/error-state transitions, and absence of prohibited
   edits.
2. **Independent QA/test verification:** inspects all three separate RED,
   GREEN, and regression result bundles,
   resolved test lists, zero-skip/zero-expected-failure results, `git diff
   --check`, and the no-overwrite, pre-create, post-create, and evidence-order
   contracts.
3. **Architect verification:** confirms ADR-005 compliance and records a new
   ADR before any deviation, especially a restored parent-continuity claim or
   broader authority.
4. **Security/privacy verification:** confirms least-privilege selected-leaf
   access, no persistence/bookmark or raw-path/key evidence, no overwrite or
   pathname cleanup, and truthful post-create handling.
5. **TPM milestone check:** confirms no Settings, V2-08, dashboard, signing,
   persistence, or scope expansion was folded into the slice and that the
   signed owner smoke is complete.
6. **Delivery Manager completion gate:** records the reviewed evidence,
   accepted owner smoke, changed-path boundary, open risks, and final decision
   in the durable delivery ledger before opening any dependent work.

No gate may be self-approved by the implementer, and no failure may be hidden
by retrying the export, changing an unrelated test, or replacing evidence.
