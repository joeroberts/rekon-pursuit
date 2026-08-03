# VD2-07x Task 2 focused test-procedure amendment

**Date:** 2026-08-01  
**Role:** Independent planning  
**Decision:** The bounded QA test-procedure correction is recorded. Task 2 may be reconsidered for implementation release only after the independent QA release review accepts this amendment and the existing Task 1 continuation gate remains satisfied.

## Scope

This amendment adds only two executable V2-07x visual proof paths and their signed companion result. It does not modify source, test code, fixtures, dashboard state, the literal 43-selector matrix, or the VD2-08 accessibility deferral.

The unchanged VD2-08 handoff tests remain the sole record for local-tab keyboard focus/Tab/Space semantics and the AI unavailable text's role/label/value. They must execute unchanged and be reported as failures when they exhibit the documented accessibility observations; they are neither skipped nor interpreted as the new visual proof.

## Required Task 2 tests

1. `testVD207ReferenceTabsSelectByPointerAtCompactWidth`
   - Launches the compact `populated` fixture, selects `sidebar-settings`, and taps each existing local selector: `settings-section-workspace`, `settings-section-recovery-archives`, `settings-section-document-references`, and `settings-section-ai-connections`.
   - After every tap, proves the corresponding section panel, the tapped selector's selected state without requiring a keyboard-focus value, and the selected global Settings rail.
   - Attaches the matching compact screenshot: `VD2-07x-compact-workspace`, `VD2-07x-compact-recovery`, `VD2-07x-compact-document-references`, and `VD2-07x-compact-ai-connections`.
   - Does not tab, press Space, or change either existing keyboard test.
2. `testVD207ReferenceAIVisualContentBoundary`
   - Launches the wide `document-relink` fixture and proves the exact Document aggregate summary `0 available · 1 require relinking`, its no-actionable-control boundary, and its no-metadata boundary.
   - Selects `settings-section-ai-connections`, then proves the visible truthful content of `settings-ai-overview-card`, `settings-ai-assistant-card`, `settings-ai-email-calendar-card`, `settings-ai-cloud-card`, and `settings-ai-privacy-card`.
   - Reasserts the AI no-actionable-control and no-metadata boundary, then attaches `VD2-07x-wide-ai-connections`.
   - Does not replace, adjust, or interpret the existing `Any` or `StaticText` semantic assertions for `settings-ai-connections-unavailable`.

## Signed execution and release evidence

Run the two tests once in the separate companion result bundle defined in the amended Task 2 brief:

~~~
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64'  \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceTabsSelectByPointerAtCompactWidth  \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceAIVisualContentBoundary  \
  -derivedDataPath /private/tmp/rekon-vd207x-task-2-companion-dd  \
  -resultBundlePath /private/tmp/rekon-vd207x-task-2-companion.xcresult
~~~

The companion result must be parseable and show each named test once with zero failures, skips, and expected failures. It is additional to—not a replacement for—the unchanged literal matrix. The release record must retain the matrix's exact carried VD2-08 accessibility outcomes, including assertion text, observed role/label/value, platform evidence, and matching VD2-08 requirement. Any non-deferred matrix failure or either companion-test failure blocks Task 2.
