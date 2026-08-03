# VD2-07x protected-export dialog unification — QA recheck

**Date:** 2026-08-02
**Role:** Fresh independent QA/test recheck
**Scope:** Approved dialog-unification design, amended implementation plan,
prior QA gate, and the current presentation/test seams. No production or test
source was changed and no owner-native flow was performed by this review.

## Verdict: ACCEPT — plan amendment complete

The amended plan concretely closes each of the three QA conditions from the
prior gate. This is an acceptance of the implementation plan and its release
procedure, not evidence that the dialog implementation or owner-native flow
has already passed.

## Amendment verification

| Mandatory amendment | Independent recheck | Result |
| --- | --- | --- |
| Actual overlay dismissal after Cancel | The proposed root callback invokes the existing cancellation action, sets the root in-progress presentation state to false, and clears the re-entry state. The custom control preserves cancel-role and Escape semantics while delegating only to that callback. The new UI contract then requires the controlled error and entry title to be absent, zero sheets, and the launch action to return after Cancel. This proves removal of the app-owned overlay rather than merely rediscovering a control behind it. | **Accept** |
| Complete existing model-regression set and inspectable results | The amended focused command names all nine required existing protections: review failure retention; invalid filename correction; reviewed-export cancellation; in-flight confirmed-export cancellation; unavailable selected-leaf correction; post-create failure feedback; verified-write-only safe success; no success on any non-success branch; and success clearing on every workspace transition. Each named method exists in the current model suite. Both the focused UI and model commands request a summary and detailed test-result view; post-implementation evidence must show every selected test executed once with zero skips and zero expected failures. | **Accept** |
| Owner-only native confirmation/success checklist | The signed Debug owner procedure is expressly state-only and keeps sensitive material local. It requires attestation of the custom entry dialog, the native chooser in front of it, return to a custom confirmation dialog rather than a stock sheet with safe facts only, and dismissal of the in-progress dialog before unchanged success appears after verified completion. Its recorded evidence is restricted to pass/fail state observations. | **Accept** |

The nine selected model methods are:

- `testProtectedExportReviewFailureRemainsVisibleForCorrection`
- `testProtectedExportInvalidFilenameUsesExactCorrectionMessage`
- `testCancellingReviewedProtectedExportClearsReviewWithoutWritingOrChangingActiveWorkspace`
- `testCancellingConfirmedProtectedExportInvalidatesInFlightOperation`
- `testProtectedExportUnavailableSelectedLeafConfirmUsesExactCorrectionMessage`
- `testProtectedExportPostCreateFailureRetainsMayRemainFeedback`
- `testVerifiedProtectedExportPublishesSafeSuccessAndRootPresentationOnlyAfterRealWriting`
- `testProtectedExportSuccessRemainsNilForEveryNonSuccessBranch`
- `testProtectedExportSuccessClearsForEveryWorkspaceTransition`

## Test-first and deferral boundaries

The sequence remains test-first: it adds the focused invalid-key UI contract,
runs it as an executable RED before any production edit, and requires the
focused UI and all nine existing model protections as GREEN evidence after the
bounded change. The current baseline remains the stock-sheet presentation, so
the proposed UI method is a prospective RED contract rather than a test added
after the visual replacement.

VD2-08 accessibility remains untouched. The plan explicitly excludes that
work, retains the existing identifiers, prohibits new or changed accessibility
identifiers for this visual slice, and does not relax deferred tests,
fixtures, or accessibility assertions.

## Release condition

A fresh implementer may be released for this one visual-only slice only after
the remaining independent planning, architecture, TPM, and delivery releases
are recorded. Do not accept the implementation or advance VD2-08 on this
plan-only decision. Final delivery acceptance still requires the specified
single-failure RED, GREEN result bundles with the required execution evidence,
a signed Debug build and clean scoped diff, independent code/QA/security
reviews, and the owner-only native checklist recorded as passed.
