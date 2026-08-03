# VD2-07x — VD2-08 accessibility deferral addendum

**Date:** 2026-08-01
**Decision source:** Product owner: “accessibility issues should be addressed in VD2-08.”

## Decision

The remaining local Settings keyboard-focus handoff and AI label/value accessibility regressions are **deferred to VD2-08**. They no longer block the approved VD2-07x reference-faithful visual implementation or its product-owner visual handoff.

This is a scope and acceptance decision, not a test waiver. It supersedes only the conflicting V2-07x Task 1/Task 2 requirements that demand every keyboard-focus or AI accessibility assertion pass before visual implementation can proceed. It does not authorize a source, test, fixture, route, state, persistence, export, or privacy change in this addendum.

## What remains a V2-07x gate

1. The deterministic archive fixture date remains a V2-07x baseline requirement. `VisualFixtureLaunchConfiguration.fixedNow` must remain `2025-05-06T12:00:00Z`, and the archive assertion must remain `created=2025-05-06T12:00:00Z;expires=2025-06-05T12:00:00Z;lifecycle=Verified`. A date/fixture failure blocks V2-07x; it is not accessibility debt.
2. The four protected-export event/root contracts and their lower-layer safety coverage remain required and green. The success event remains filename-only, follows a real verified write only, is absent on all cancellation/failure/stale/workspace-transition paths, and remains root-owned. No test fixture, default, or demo may produce export success.
3. The approved four Settings surfaces, unchanged global rail, local non-persisted section selection, truthful Recovery/Workspace/Document/AI content, aggregate/no-control/privacy boundaries, real-success-only dialog, cancellation/error behavior, and signed visual evidence remain V2-07x acceptance requirements.
4. Every existing test remains in the source tree with its assertions and identifiers intact. This addendum permits no `XCTSkip`, `XCTExpectFailure`, retry workaround, guarded continuation, deleted assertion, weakened predicate, or hidden-check accommodation.

## Exact V2-07x test treatment

Run the literal signed V2-07x matrix and retain its result bundle/logs. Its accessibility observations must be reported separately; they must not be concealed or converted to passing results.

For V2-07x release classification:

- The fixed-date fixture/host assertions, all protected-export and lower-layer selectors, global-rail/route checks, recovery action/error/cancellation checks, privacy/no-metadata/no-control checks, and the approved visual/card/dialog assertions are blocking and must pass with zero skip or expected failure.
- The existing `testVD207ReferenceTabsKeepKeyboardSelectionAtCompactWidth` and `testVD207SettingsSecondaryNavigationIsKeyboardOperableAtCompactWidth` remain unchanged and execute as recorded VD2-08 handoff evidence. A failure may be carried forward only when it is specifically the existing semantic keyboard-focus value/Tab/Space handoff. Any missing control, selected-rail, route, panel, layout, or other behavior failure still blocks V2-07x.
- The existing `testVD207SettingsDocumentAndAISectionsStayAggregateAndUnavailable` remains unchanged and executes as recorded VD2-08 handoff evidence. A failure may be carried forward only when it is specifically the AI informational text's accessibility role, label, or value. Aggregate counts, visible truthful copy, privacy, metadata, or no-actionable-control failures still block V2-07x.
- To prove V2-07x visual behavior independently of a carried accessibility failure, Task 2 adds focused **pointer-selection** coverage for the four compact local tabs and a focused AI visual/content boundary check. These tests must preserve the same selectors, panel selection, global Settings rail, visible copy, aggregate/no-control/privacy conditions, and wide/compact screenshot attachment requirements. They must not alter the deferred keyboard/AI tests or use test-only state.
- A release report must list each carried result with its exact test name, failing assertion, actual accessibility role/label/value, platform/run evidence, and the matching VD2-08 regression requirement below. It must explicitly state that the test was run and failed; it cannot call the matrix fully green.

## VD2-08 durable regression handoff

VD2-08 must own and close these requirements before it is marked complete:

1. At compact and wide Settings widths, every existing local section control (`settings-section-workspace`, `settings-section-recovery-archives`, `settings-section-document-references`, and `settings-section-ai-connections`) is reachable by Tab, exposes the exact selected/not-selected semantic value including keyboard focus, activates with Space, displays the matching panel, and retains the selected global Settings rail.
2. The AI-unavailable informational text keeps its current truthful local-only/no-connection copy and identifier while exposing a stable semantic text role with correct accessible label/value. Its regression test must retain the `Any` query and explicit `StaticText` query, together with the Document/AI no-actionable-control and no-metadata checks.
3. VD2-08 must run the original two keyboard tests and the existing Document/AI test without relaxation, plus any necessary new deterministic accessibility regression tests. It must record a parseable signed result bundle and no skip/expected-failure classification for those requirements.

## Non-goals and safety boundary

This deferral does not reopen fixture time, recovery/archive/export semantics, the protected-export operation token, root-dialog ownership, document metadata privacy, AI/cloud/Gmail/Calendar capability, global navigation, or local Settings persistence. It creates no new UI behavior and is not an approval to weaken hidden checks.
