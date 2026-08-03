# VD2-07x Baseline-Repair Prerequisite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the deterministic Settings/fixture baseline so the existing VD2-07x Task 1 matrix has only its declared reference-visual RED failures before Task 2 renders the approved reference screens.

**Architecture:** This is a repair of three verified baseline defects, not a redesign. The fixture clock becomes the date already required by the signed archive assertions; the existing local Settings selectors adopt the repository's working semantic-focus modifier pattern; and the existing AI-unavailable copy remains a `Text` accessibility element. No recovery/export/data behavior, root event seam, global rail, selector identity, tab composition, or Task 2 card/dialog rendering changes.

**Tech Stack:** Swift 6, SwiftUI for macOS, XCTest/XCUITest, the existing signed Debug `RekonPursuit` scheme.

## Global Constraints

- The approved reference-faithful Settings design at `docs/superpowers/specs/2026-08-01-vd207-reference-faithful-recovery-screen-design.md` remains controlling; this task must not render its tabs, cards, status icons, responsive layout, or success dialog.
- The global app rail and the four local Settings section identifiers remain unchanged. Local selection remains non-persisted and defaults to Recovery & archives.
- Preserve every existing recovery/archive/export/purge/restore action, disabled/busy/error/cancel behavior, document aggregate boundary, AI unavailability, and protected-export success event behavior.
- Do not add a fixture mode, launch argument, demo success, mock destination, network capability, store/schema/migration change, raw path/key/document metadata, test skip, expected failure, or result-bundle workaround.
- The worktree is dirty. Preserve unrelated user changes; do not reset, revert, reformat, bulk-stage, or edit any file outside this plan's allowlist.
- An implementer stages and commits nothing. A later Delivery Manager may consider a checkpoint only after independent acceptance and the untracked-file integration gate in Step 6 has produced clean evidence; a scratch-index hunk check is boundary evidence only and is never build evidence.

## Evidence and root cause

| Matrix symptom | Reproduced evidence | Root cause | Repair boundary |
| --- | --- | --- | --- |
| Archive summary is May 1/May 31 instead of May 6 noon/June 5 | `/private/tmp/rekon-vd207x-task-1-red-terminal.log` reports `created=2025-05-01T00:00:00Z;expires=2025-05-31T00:00:00Z`; `date -u -r 1746057600` returns 2025-05-01T00:00:00Z | `VisualFixtureLaunchConfiguration.fixedNow` has a May 6 comment but a May 1 epoch literal. | One fixture-clock literal plus a direct fixed-time test assertion. |
| Compact Settings buttons never expose `Keyboard focus` and Space cannot select a tab | The focused compact rerun logs four failed focus probes and values remain `Not selected`; both new and existing VD2-07 Settings keyboard tests fail. | `SettingsView.sectionSelector` omits the working `Button` focus-surface modifiers used by `ContactsView` (`.buttonStyle(.plain)`, `.focusEffectDisabled(true)`, and explicit label). Its `@FocusState` therefore never reaches the accessibility value under this host's tab traversal. | Only the existing selector modifier chain; no new state, route, or layout. |
| Existing aggregate Document/AI test finds the AI element as `Any` but not as `StaticText` | The signed matrix reaches `settings-ai-connections-unavailable`, then the three static-text label assertions fail. The current test queries only `app.descendants(matching: .any)`, so it does not prove the role defect. | The existing `Text` is given a custom `.accessibilityLabel`, which changes the host's exposed accessibility role. The visible copy already contains the required truthful facts. | Add one explicit `app.staticTexts` role assertion beside the existing `Any` query, prove it RED, then remove only the overriding label so the `Text` retains its normal static-text role and copy. |

The Task 1 report at `.superpowers/sdd/2026-08-01-vd207-reference-faithful-recovery-screen/task-1-report.md` records the same three defects. It also records an incomplete result bundle caused by post-test XCTest runner finalization; this task does not modify or mask that tooling issue.

## File structure

| File | Responsibility in this prerequisite |
| --- | --- |
| `RekonPursuit/RekonVisualTheme.swift` | Correct the single deterministic visual-fixture instant used to seed the archive and its thirty-day expiry. |
| `RekonPursuit/SettingsView.swift` | Keep the existing placeholder Settings UI functional by exposing keyboard focus on the actual section buttons and retaining AI-unavailable copy as static text. |
| `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift` | Make the fixed-date contract explicit, so the wrong epoch cannot silently match its own value again. |
| `RekonPursuitUITests/RekonPursuitUITests.swift` | Retain every signed UI expectation; remove only the two temporary guarded continuations from the compact reference contract if present, and add the one explicit AI `StaticText` role assertion while retaining the existing `Any` query and its assertions. |

## Single bounded task: repair the Task 1 baseline

**Files:**

- Modify: `RekonPursuit/RekonVisualTheme.swift:1349` — the `fixedNow` literal only.
- Modify: `RekonPursuit/SettingsView.swift:202-239` — `sectionSelector(_:)` modifiers only.
- Modify: `RekonPursuit/SettingsView.swift:414-421` — `AIConnectionsSettingsSection` accessibility modifier only.
- Modify: `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift:356-368` — extend `testVisualFixtureUsesFixedTimeAndReducedMotionContracts`.
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift:2780-2819` — remove only the temporary `guard section.exists else { continue }` continuations, if present.
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift:3003-3016` — add only the explicit `app.staticTexts["settings-ai-connections-unavailable"]` role assertion beside the existing `Any` query; do not replace or relax that query or any of its assertions.

**Consumes:** the existing Task 1 protected-export event/root seam and the already-signed 43-selector test set.

**Produces:** an honest pre-Task-2 result: 40 green selectors — 24 Core/ViewModel, nine fixture-host, and seven UI. The seven UI passes are the six ordinary UI methods plus `testVD207ReferenceRecoveryDoesNotInventExportSuccess`. `testVD207ReferenceRecoveryDashboardKeepsRailAndUsesCardComposition`, `testVD207ReferenceTabsKeepKeyboardSelectionAtCompactWidth`, and `testVD207ReferenceOtherSettingsSectionsUseTruthfulInformationalCards` fail only in their respectively declared visual-selector activities (10 + 2 + 12 = 24 activities).

### TDD steps

- [ ] **Step 1: Add and prove the fixed-date regression contract.**

  Extend the existing host test immediately after its `configuration.now == fixedNow` assertion:

  ```swift
  let formatter = ISO8601DateFormatter()
  XCTAssertEqual(
      formatter.string(from: VisualFixtureLaunchConfiguration.fixedNow),
      "2025-05-06T12:00:00Z"
  )
  ```

  Run:

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testVisualFixtureUsesFixedTimeAndReducedMotionContracts -derivedDataPath /private/tmp/rekon-vd207x-baseline-date-red-dd -resultBundlePath /private/tmp/rekon-vd207x-baseline-date-red.xcresult
  ```

  Expected before the source correction: the exact ISO assertion fails with the current May 1 value. Do not change the UI assertion's required May 6 value instead.

- [ ] **Step 2: Correct the fixture source value and prove archive truth.**

  Replace only the erroneous `fixedNow` epoch literal with `1_746_532_800`, which is 2025-05-06T12:00:00Z. Retain the UTC timezone and the existing thirty-day archive-expiry computation.

  Re-run the focused host test from Step 1 and then:

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testArchiveVisualFixtureSeedsVerifiedArchiveCatalogue -derivedDataPath /private/tmp/rekon-vd207x-baseline-archive-dd -resultBundlePath /private/tmp/rekon-vd207x-baseline-archive.xcresult
  ```

  Expected: both tests pass, and the seeded archive remains one verified catalogue row created at the fixed time with an expiry thirty calendar days later. Do not alter fixture construction, identity, launch parsing, or archive tests.

- [ ] **Step 3: Restore semantic compact tab focus using the repository's working Button pattern.**

  Treat these existing UI assertions as the failing regression tests; do not weaken their expected values:

  ```swift
  XCTAssertEqual(document.value as? String, "Not selected; Keyboard focus")
  app.typeKey(.space, modifierFlags: [])
  XCTAssertEqual(document.value as? String, "Selected; Keyboard focus")
  ```

  In the existing `sectionSelector(_:)` chain, add only the equivalent focus-surface modifiers already used by `ContactsView`:

  ```swift
  .buttonStyle(.plain)
  .focusable()
  .focused($focusedSection, equals: section)
  .onKeyPress(.space) {
      selectedSection = section
      return .handled
  }
  .focusEffectDisabled(true)
  .accessibilityLabel(section.title)
  .accessibilityValue(selectorAccessibilityValue(for: section))
  .accessibilityIdentifier(section.accessibilityIdentifier)
  .accessibilityAddTraits(selectedSection == section ? .isSelected : [])
  ```

  Do not add a pointer-focus suppression state: the required value is the actual focus state after tab traversal, and pointer activation must still select the same local section. Keep the existing `selectedSection`, `focusedSection`, `ViewThatFits`, labels, identifiers, and Space handler.

  If the Task 1 compact reference method still has `guard section.exists else { continue }`, delete only those two guards. The immediately preceding existence assertions remain and must cause a genuine baseline fault; they must not be bypassed to manufacture a visual RED report.

  Run the two current green-baseline contracts:

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsSecondaryNavigationDefaultsToRecoveryAndKeepsGlobalRail -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsSecondaryNavigationIsKeyboardOperableAtCompactWidth -derivedDataPath /private/tmp/rekon-vd207x-baseline-keyboard-dd -resultBundlePath /private/tmp/rekon-vd207x-baseline-keyboard.xcresult
  ```

  Expected: both pass; the tab loop exposes exact selected/non-selected focus values, Space selects the local panel, and `sidebar-settings` remains selected.

- [ ] **Step 4: Add and prove the AI static-text role contract, then preserve AI truth.**

  In `testVD207SettingsDocumentAndAISectionsStayAggregateAndUnavailable`, retain the existing `Any` query and every current assertion. Immediately after the existing `unavailable` assertions, add this separate role contract:

  ```swift
  let unavailableStaticText = app.staticTexts["settings-ai-connections-unavailable"]
  XCTAssertTrue(unavailableStaticText.waitForExistence(timeout: 2))
  XCTAssertTrue(unavailableStaticText.label.contains("No AI requests"))
  XCTAssertTrue(unavailableStaticText.label.contains("Gmail"))
  XCTAssertTrue(unavailableStaticText.label.contains("Calendar"))
  ```

  Run the focused command below before changing `SettingsView`. Expected before the source correction: the existing `Any` assertions remain true, while `unavailableStaticText` fails to exist because the explicit label changes the host role. Do not delete, replace, or weaken the existing `Any` query.

  In `AIConnectionsSettingsSection`, retain the existing single `Text` string and identifier, but then remove only its explicit `.accessibilityLabel(...)`. Do not change any word in the copy, add a control, or change the Document section. Re-run the same focused command. Expected after the source correction: both the original `Any` contract and the new static-text role contract pass, with the existing aggregate/document/no-control assertions unchanged.

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsDocumentAndAISectionsStayAggregateAndUnavailable -derivedDataPath /private/tmp/rekon-vd207x-baseline-ai-dd -resultBundlePath /private/tmp/rekon-vd207x-baseline-ai.xcresult
  ```

  Do not treat a result as evidence if the new query has not first been shown RED against the current override and then green after only the override removal.

  The existing no-control assertions remain required:

  ```swift
  XCTAssertEqual(aiPanel.descendants(matching: .button).count, 0)
  XCTAssertEqual(aiPanel.descendants(matching: .link).count, 0)
  XCTAssertEqual(aiPanel.descendants(matching: .textField).count, 0)
  ```

- [ ] **Step 5: Re-run the signed matrix and classify only the intended visual RED.**

  Run the literal 43-selector command in `docs/delivery/task-briefs/VD2-07x-baseline-repair-prerequisite.md`, using `/private/tmp/rekon-vd207x-baseline-repair-dd` and `/private/tmp/rekon-vd207x-baseline-repair.xcresult` exactly.

  Expected terminal outcome:

  - 24/24 Core/ViewModel selectors pass.
  - 9/9 fixture-host selectors pass.
  - Of the 10 UI selectors, exactly seven pass: the six ordinary UI methods plus `testVD207ReferenceRecoveryDoesNotInventExportSuccess`. The remaining three reference methods report exactly 24 `VD2-07x RED: unrendered visual selector ...` activities: ten Recovery, two compact-tab, and twelve other-section card selectors.
  - There is no compile/signing/fixture/route/focus/aggregate/recovery/action/event failure; there is no skip or expected-failure marker.

  If the XCTest runner again completes terminal suites but fails to finalize the requested result bundle, retain the terminal log and incomplete bundle outside the repository, record that as an infrastructure-evidence limitation, and do not modify application code or falsely mark the matrix released.

- [ ] **Step 6: Run the non-destructive hunk-isolation preflight, then make an explicit release decision.**

  Record `git status --short`, the normal `git diff --check`, and the full-file whitespace checks below in the implementation report. The normal diff check does not include untracked files, so it is not sufficient evidence for `SettingsView.swift` or the currently untracked host-test path:

  ```bash
  git diff --no-index --check /dev/null RekonPursuit/SettingsView.swift
  git diff --no-index --check /dev/null RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift
  ```

  The implementer stages and commits nothing. A Delivery Manager performs this preflight only after independent review accepts the repair, using a scratch index rather than the real index:

  ```bash
  repair_index="$(mktemp /private/tmp/rekon-vd207x-baseline-index.XXXXXX)"
  cp "$(git rev-parse --git-path index)" "$repair_index"
  GIT_INDEX_FILE="$repair_index" git add -N -- RekonPursuit/SettingsView.swift RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift
  GIT_INDEX_FILE="$repair_index" git add -p -- RekonPursuit/RekonVisualTheme.swift RekonPursuit/SettingsView.swift RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift RekonPursuitUITests/RekonPursuitUITests.swift
  GIT_INDEX_FILE="$repair_index" git diff --cached --name-only
  GIT_INDEX_FILE="$repair_index" git diff --cached --check
  GIT_INDEX_FILE="$repair_index" git diff --cached -- RekonPursuit/RekonVisualTheme.swift RekonPursuit/SettingsView.swift RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift RekonPursuitUITests/RekonPursuitUITests.swift
  ```

  In the interactive command, select only: the fixture epoch literal; `sectionSelector(_:)`'s `.buttonStyle(.plain)`, `.focusEffectDisabled(true)`, and explicit label additions; the one AI accessibility-label removal; the one ISO-UTC host assertion; the two compact guard removals; and the one additive AI `app.staticTexts` assertion. Reject the scratch index if any other hunk is selected, if a desired hunk cannot be split from unrelated pre-existing content, or if a Task 1 event/root hunk appears. Preserve the real index throughout; do not run `git add -N`, `git add -p`, `git reset`, or `git restore` against it.

  A partial scratch-index entry for an untracked file is only a boundary inspection artifact. It is not a syntactically complete source/test file, must never be compiled, and must not be called a hunk-isolated build checkpoint.

  **Release decision:** If the scratch diff cannot cleanly isolate each allowed repair hunk *and* an actual checkpoint would require staging the untracked `SettingsView.swift` or untracked host-test file in full, Delivery records this prerequisite as **unreleasable on the current worktree**. Do not stage the full file as a workaround. The only next actions are a separately reviewed, owner-authorized baseline-integration checkpoint that adopts the pre-existing files before this repair, or a clean worktree based on an approved commit that already tracks those files. Either option requires fresh preimplementation reviews against that new base before this repair is released. If clean isolation is evidenced on an approved tracked base, a subsequent Delivery review may decide whether to create a checkpoint; this plan makes no claim that a hunk-only source index compiles.

## Dependencies, risks, and release gates

1. This prerequisite is released before another Task 1 signed-matrix attempt and before Task 2 visual rendering.
2. Because it intentionally corrects a fixture defect that was excluded from Task 1's original allowlist, a fresh Architecture, QA, Security/privacy, TPM, and Delivery review must approve this brief before implementation. The correction has no security-boundary effect, but its date shifts deterministic fixture output and therefore needs independent verification.
3. The existing Task 1 protected-export event/root hunks remain unaccepted and unstaged. This task neither absorbs nor alters them; it only allows their required matrix to be truthfully classified.
4. The Xcode runner's result-bundle finalization stall is not a product defect and is out of repair scope. A complete parseable result bundle remains necessary before a delivery release can claim the signed matrix is verified.
5. After this task is accepted, a fresh QA verifier must confirm the exact 24-activity RED classification, then the normal Task 1 code-review/QA/architecture/security/TPM/delivery gates decide whether Task 2 may start.

## Self-review

- **Spec coverage:** Every matrix blocker identified in `task-1-report.md` has one source cause, one test contract, and one verification route. The approved reference surfaces remain expressly excluded.
- **Placeholder scan:** No task contains a deferred implementation step or an unspecified test expectation.
- **Interface consistency:** The plan retains current `SettingsSection`, `SettingsView`, `VisualFixtureLaunchConfiguration`, and test method names; it introduces no new runtime interface.
