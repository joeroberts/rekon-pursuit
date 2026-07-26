# UX-R1 Home and Pipeline Amendment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Home the default daily destination and make Pipeline own existing add/import entry points without changing persisted data or UX-R2 form/import semantics.

**Architecture:** Keep `ContentView` as the sole owner of `WorkspaceViewModel`, native picker/sheet bindings, and route state. Separate sidebar-visible destinations from internal Add/Import destinations in `AppShellView`; retain the latter as ephemeral `ContentView.page` values. Reuse `RekonTheme` rather than adding a styling system.

**Tech Stack:** SwiftUI, Swift, existing local `WorkspaceViewModel`, Xcode test target.

## Global Constraints

- No SQLite/model/migration/activity/task/reconciliation/network/file-access change.
- Home contains the existing Needs Attention workflow; it adds no dashboard/data source.
- Sidebar: Home, Pipeline, Contacts, Activity & AI, Settings only.
- Add Opportunity and Import CSV stay existing internal routes entered from Pipeline; their UX-R2 redesign is excluded.
- Use focused local verification only; no CI, coverage target, or live network work.

## File map

- Modify: `RekonPursuit/AppShellView.swift` — sidebar-visible destination collection and semantic theme helpers only if needed.
- Modify: `RekonPursuit/ContentView.swift` — default Home route, Home view, Pipeline actions/empty layout, and route wiring.
- Modify: `RekonPursuitTests/WorkspaceViewModelTests.swift` or existing focused navigation test location — route/no-mutation coverage at the lowest practical layer.
- Modify only if assertions exist: `RekonPursuitUITests/RekonPursuitUITests.swift` — sidebar reachability identifiers; do not create a new harness.

---

### Task 1: Separate sidebar destinations from internal Pipeline routes

**Files:**

- Modify: `RekonPursuit/AppShellView.swift`
- Modify: `RekonPursuit/ContentView.swift`
- Test: existing focused navigation/UI test file, if present

**Interfaces:**

- Consumes: `AppDestination`, `AppShellView.selectDestination(_:)`, and `ContentView.page`.
- Produces: `AppDestination.home`; a sidebar collection excluding internal `.addOpportunity` / `.importCSV`; internal route selection callbacks owned by `ContentView`.

- [ ] **Step 1: Write the failing focused route assertion**

Assert a fresh ready shell selects Home and test the sidebar collection:

```swift
XCTAssertEqual(initialDestination, .home)
XCTFalse(sidebarDestinations.contains(.addOpportunity))
XCTFalse(sidebarDestinations.contains(.importCSV))
```

- [ ] **Step 2: Run the focused assertion to verify the old route fails**

Run the existing navigation test target. Expected: the initial destination is `.needsAttention` or removed entries are present.

- [ ] **Step 3: Write the minimal route split**

Rename the sidebar case to `.home = "Home"`, retain `.addOpportunity` and `.importCSV` as internal cases, and expose:

```swift
static let sidebarDestinations: [AppDestination] = [
    .home, .pipeline, .contacts, .activityAndAI, .settings
]
```

Render `sidebarDestinations` in `AppShellView`. Initialize `ContentView.page` to `.home`; render its Home view from the former Needs Attention task source. Add `showAddOpportunity()` and `showImportCSV()` in `ContentView` that clear any safely-leavable opportunity route and select the existing internal destination.

- [ ] **Step 4: Run the focused route assertion**

Expected: Home is default; sidebar exposes only the five approved destinations; Add/Import remain selectable through explicit internal callbacks.

- [ ] **Step 5: Commit the bounded route change**

Commit only the affected shell/content/test files with message `feat: make Home the default Pipeline entry point`.

### Task 2: Build Home and Pipeline entry/empty states with semantic tokens

**Files:**

- Modify: `RekonPursuit/ContentView.swift`
- Modify: `RekonPursuit/AppShellView.swift` only if a missing semantic button/surface helper is genuinely required
- Test: existing focused UI/navigation smoke only

**Interfaces:**

- Consumes: `WorkspaceViewModel.needsAttention`, `WorkspaceViewModel.filteredOpportunities`, existing `openAttentionTask`, `showAddOpportunity()`, `showImportCSV()`, and `RekonTheme`.
- Produces: Home with Needs Attention first, Pipeline primary/secondary entry actions, and responsive empty content regions.

- [ ] **Step 1: Write failing focused UI/reachability checks**

Add non-mutating assertions:

```swift
XCTAssertTrue(app.buttons["pipeline-add-opportunity"].exists)
XCTAssertTrue(app.buttons["pipeline-import-csv"].exists)
XCTFalse(app.buttons["sidebar-add-opportunity"].exists)
XCTFalse(app.buttons["sidebar-import-csv"].exists)
```

Do not assert pixels or a fixed position.

- [ ] **Step 2: Run focused checks to show the old shell fails**

Expected: Pipeline actions are absent and old sidebar entries exist.

- [ ] **Step 3: Write responsive content composition**

Make Home's title "Home" and render a first Needs Attention section. For no tasks, use a flexible post-header region:

```swift
VStack(spacing: 12) {
    ContentUnavailableView(...)
    Button("Add an opportunity", action: showAddOpportunity)
        .accessibilityIdentifier("home-add-opportunity")
}.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
```

Keep real task cards in their scrolling list. In `PipelineView`, add an action bar after the title/header:

```swift
Button("Add opportunity", action: showAddOpportunity)
    .buttonStyle(.borderedProminent)
    .accessibilityIdentifier("pipeline-add-opportunity")
Button("Import CSV", action: showImportCSV)
    .accessibilityIdentifier("pipeline-import-csv")
```

Use existing accent/surface/border tokens for primary, secondary, field, selection, and empty surfaces. Keep filters above the flexible centered no-results region. Do not restyle Add Opportunity or CSV form internals.

- [ ] **Step 4: Run focused checks and a Debug build**

Run focused navigation/workspace/task checks plus the repository Debug macOS build. Expected: build succeeds; actions route without writing a task, activity, reconciliation result, or opportunity.

- [ ] **Step 5: Commit the Home/Pipeline composition**

Commit only the affected shell/content/test files with message `feat: add Home and Pipeline workflow entry points`.

### Task 3: Perform focused isolated smoke and record handoff evidence

**Files:**

- Modify: `docs/delivery/remediation-ledger.md` and `docs/delivery/dashboard-status.json` only if Delivery moves UX-R1 state
- Regenerate: `docs/delivery/dashboard/index.html` and `docs/delivery/dashboard/remediation.html` only on that state transition

**Interfaces:**

- Consumes: completed Tasks 1–2 and the existing isolated temporary-app smoke procedure.
- Produces: redacted user-visible evidence for independent QA/reviewer and product-owner acceptance; no new persistent application behavior.

- [ ] **Step 1: Build a uniquely named isolated Debug app**

Use the existing isolated derived-data/test namespace. Never use or alter the product-owner workspace.

- [ ] **Step 2: Execute the short smoke**

At compact and wide window sizes: create a disposable workspace; verify Home launches first; create/open a task; return Home; open Pipeline; open Add then return; open Import then return; filter to no match; resize; confirm controls do not overlap and empty content remains centered below header/filters.

- [ ] **Step 3: Verify no contract regression**

Run existing R1a workspace, task action, CSV, and R4/R5 targeted checks. Verify navigation alone produces no unexpected app data, migration, network action, or activity event.

- [ ] **Step 4: Record only the delivery-state outcome**

If independent implementation review and product-owner hands-on review accept the slice, then update JSON, ledger, and generated dashboard together. Do not mark UX-R1 accepted from a build or smoke alone.

## Self-review

- Spec coverage: Home default/Needs Attention first is Tasks 1–2; sidebar and Pipeline ownership is Tasks 1–2; token consistency and responsive empty states are Task 2; no data-semantic expansion is enforced globally and verified in Task 3.
- Explicitly excluded UX-R2 form/CSV/contact work is not assigned to any task.
- No placeholder action, undocumented interface, or dependency on a new service is introduced.
