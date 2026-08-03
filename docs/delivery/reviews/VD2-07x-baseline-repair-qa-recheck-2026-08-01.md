# VD2-07x baseline-repair prerequisite — QA recheck

**Date:** 2026-08-01
**Role:** Independent QA/test reviewer
**Verdict:** **ACCEPT — bounded prerequisite planning only**

## Scope and method

Rechecked the original QA **NEEDS CHANGE** review, the amended prerequisite
plan and brief, the Task 1 implementation report, the controlling Task 1
brief, and the current Settings/fixture/UI-test source. This is a static
pre-implementation gate; no source, test, fixture, project, index, or commit
was changed, and no signed matrix result is claimed by this review.

## Rechecked corrections

1. **Literal matrix is exact.** Extracting the Task 1 command block from the
   controlling brief and the `Exact 43-selector matrix` block from the
   prerequisite brief produced no ordered diff. Each has 43 unique selectors:
   10 `RekonPursuitUITests`, 9 `RekonPursuitUITestHostTests`, and 24
   `RekonPursuitTests`. The repair brief therefore retains the complete signed
   baseline rather than narrowing it.

2. **The acceptance arithmetic is now correct.** The amended plan and brief
   require 24 Core/ViewModel passes, 9 fixture-host passes, and 7 UI passes
   (the six ordinary Settings methods plus
   `testVD207ReferenceRecoveryDoesNotInventExportSuccess`): 40 green
   selectors in total. The only remaining three methods are explicitly
   classified as visual RED: 10 Recovery selector activities, 2 compact-tab
   activities, and 12 other-section card activities — exactly 24 activities.
   The acceptance rule also excludes all other compile, signing, fixture,
   archive-date, rail, focus, aggregate, action, event, route, error,
   cancellation, skip, and expected-failure results.

3. **The AI role repair is test-first and additive.** The amended allowlist
   preserves the existing `app.descendants(matching: .any)` query and all of
   its assertions, then adds the explicit
   `app.staticTexts["settings-ai-connections-unavailable"]` existence and
   copy assertions. It requires that additive assertion to fail while the
   current explicit accessibility-label override remains, then to pass after
   only that override is removed. Current source confirms the prerequisite is
   real: the UI test has only the `Any` query at
   `RekonPursuitUITests/RekonPursuitUITests.swift:3006-3010`, while
   `RekonPursuit/SettingsView.swift:411-414` still applies the explicit label.
   The no-control, aggregate, and disclosure checks remain required.

4. **The remaining two baseline causes are likewise reproducible and bounded.**
   `VisualFixtureLaunchConfiguration.fixedNow` still contains the May 1 epoch
   beside the required May 6 comment, and the host test lacks the direct ISO
   assertion. `SettingsView.sectionSelector(_:)` still lacks the planned
   plain-button, focus-effect, and explicit-label modifiers; the compact
   reference test still has both temporary guarded continuations. The plan
   authorizes only the stated literal/modifier/guard/test hunks and retains
   the existing exact focus and Space-selection assertions.

5. **The untracked-file release condition is now explicit and safe.**
   `RekonPursuit/SettingsView.swift` and
   `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift` are
   currently untracked. The amended documents require a later Delivery-owned
   scratch-index preflight, full cached-diff/whitespace inspection, and
   separate no-index whitespace checks; the real index must remain untouched.
   They correctly state that a partial intent-to-add entry is boundary
   evidence, never a compileable checkpoint. If the exact repair hunks cannot
   be isolated or a real checkpoint would require staging either untracked
   file in full, Delivery must mark the prerequisite unreleasable on this
   worktree and require an owner-authorized baseline integration or clean
   approved base with fresh review. This review does not waive or satisfy that
   later condition.

## QA release condition

The prior QA blockers in the planning artifacts are resolved. A fresh
implementer may perform only the four-path, test-first prerequisite described
in the amended brief and plan. Task 2 remains blocked until the repair has
the required focused evidence, a parseable signed-matrix result with the
40-green/24-visual-RED classification, independent post-implementation
review, and the Delivery scratch-index decision above. An incomplete
`xcresult` runner artifact remains infrastructure evidence only and cannot
substitute for the matrix result.
