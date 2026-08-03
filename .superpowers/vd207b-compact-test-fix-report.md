# VD2-07b compact layout test correction

## Scope

Changed only `RekonPursuitUITests/RekonPursuitUITests.swift`.

`testVD207bCompactAndLargeTextControlLayout` continues to use
`contact-detail-scroll` for the wide Contacts editor. For compact Contacts, it
now verifies the source-backed `contact-compact-detail` layout, keeps the two
multiline editor assertion, enters a non-persisted draft name to enable Save,
finds the compact scroll view by its contained `save-contact` control, and
requires both Cancel and Save to be reachable. No production source, fixture,
dashboard, roadmap, native panel behavior, or recovery-key path changed.

## Verification

Focused signed Debug run:

```sh
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207bCompactAndLargeTextControlLayout \
  -derivedDataPath /private/tmp/rekon-vd207b-compact-fix-final-dd \
  -resultBundlePath /private/tmp/rekon-vd207b-compact-fix-final.xcresult
```

Result: 1 executed; 8 failures, all expected `VD2-07b RED` additive
shared-control-surface projections. The compact baseline layout, scroll, and
action-reachability checks passed.

Task 1 signed Debug matrix:

```sh
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207bSharedFormControlAlignmentAcrossContactsPipelineAndActivity \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207bOpportunityEditorsRetainBindingsValidationAndNoSaveBack \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207bSettingsRecoveryFieldsRetainRootOwnershipAndFilePanelsRemainNative \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207bCompactAndLargeTextControlLayout \
  -derivedDataPath /private/tmp/rekon-vd207b-compact-fix-matrix-dd \
  -resultBundlePath /private/tmp/rekon-vd207b-compact-fix-matrix.xcresult
```

Result: 4 executed; 69 failures, all 69 expected `VD2-07b RED` additive
shared-control-surface projections; zero baseline failures. The build used the
configured Debug Apple Development signing identity. Result bundle:
`/private/tmp/rekon-vd207b-compact-fix-matrix.xcresult`.

`git diff --check` passed.

## Commit

The test correction is committed in the repository history; the exact commit
is reported with this handoff.
