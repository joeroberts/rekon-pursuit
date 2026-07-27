# Contact Opportunity Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace duplicate inline contact-opportunity sections with one explicit, focused relationship-management surface.

**Architecture:** `ContactsView` retains the contact form and exposes one relationship-management action when editing a contact. A sheet receives the selected contact's linked opportunities and other active opportunities at its employer; the latter excludes linked records. Existing ViewModel link, unlink, and open callbacks remain the data boundary.

**Tech Stack:** SwiftUI, existing `WorkspaceViewModel`, XCTest.

## Global Constraints

- Do not create links implicitly from an employer association.
- A linked opportunity must appear once only, under Linked opportunities.
- Keep the change local to the Contacts workflow and use no new dependencies.

---

### Task 1: Focused opportunity relationship sheet

**Files:**
- Modify: `RekonPursuit/ContentView.swift`
- Test: `RekonPursuitTests/WorkspaceViewModelTests.swift`

- [ ] **Step 1: Write a failing test**

Add a ViewModel test with a contact linked to one Microsoft opportunity and another unlinked Microsoft opportunity. Assert the employer candidate collection excludes the linked opportunity.

- [ ] **Step 2: Run the focused test and verify it fails**

Run: `xcodebuild test -quiet -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testEmployerOpportunityCandidatesExcludeLinkedContactOpportunities`

- [ ] **Step 3: Implement the minimal UI**

Replace the persistent Employer opportunities and Linked opportunities groups with `Manage linked opportunities (N)`. Its sheet contains a Linked opportunities section with Open and Unlink controls, then an Other opportunities at <employer> section with Link controls. Do not render the second section when no candidate exists.

- [ ] **Step 4: Run focused verification**

Run the test from Step 2, `git diff --check`, and a Debug macOS build verified with `codesign --verify --strict`.

- [ ] **Step 5: Commit and push**

Commit the focused implementation and open the signed Debug app for product-owner verification.
