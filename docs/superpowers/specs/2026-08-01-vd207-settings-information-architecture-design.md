# VD2-07 — Settings information architecture design

**Date:** 2026-08-01
**Status:** Product-owner design approved; implementation is not released.
**Scope:** Recompose the existing Settings screen into sub-navigation and
truthful local status surfaces without changing recovery, export, archive,
purge, restore, document-reference, AI, cloud, Gmail, Calendar, or network
behavior.

## Decision

Settings uses local sub-navigation with four sections:

1. **Workspace**
2. **Recovery & archives**
3. **Document references**
4. **AI & connections**

The selected section is Settings-local presentation state. It is not a global
route, is not persisted, and does not modify the active workspace. The existing
global application rail remains unchanged and continues to own Home, Pipeline,
Contacts, Activity & AI, and Settings. Within the Settings page, the four
local sections appear as a secondary horizontal selector below the Settings
heading; at compact widths, that selector and the selected section stack
vertically. The secondary selector is visually and semantically distinct from
the global application rail.

`Recovery & archives` is the default selected section because it carries the
highest-impact recovery, export, purge, and restore status and entry points.
The choice does not change application navigation or authorize any action.

## Components and ownership

`ContentView` remains the sole owner of:

- `WorkspaceViewModel` and workspace refresh state;
- application routes and navigation restoration;
- file importers and destination pickers;
- recovery-key enrollment, archive creation, protected-export, purge, and
  restore sheet state;
- destructive confirmations, alerts, and recovery-sheet dismissal/cancel
  behavior; and
- the separate-workspace recovery return path.

`SettingsView.swift` is extracted from `ContentView.swift`. It owns only the
local selected Settings section and composes focused presentation views:

- `WorkspaceSettingsSection`
- `RecoveryArchivesSettingsSection`
- `DocumentReferencesSettingsSection`
- `AIConnectionsSettingsSection`

The focused views receive display-safe state plus closures to pre-existing
actions. They do not own the workspace model, create sheets, read recovery-key
values, use file-system paths/bookmarks/hashes, or perform persistence.

## Section contracts

### Workspace

Display only existing local retention and separate-workspace facts. The section
retains the existing return-to-preserved-workspace recovery entry point when a
separate local workspace is active. It never creates, activates, switches, or
deletes a workspace.

### Recovery & archives

Keep every accepted recovery action available and behaviorally identical:

- recovery-key setup when not enrolled;
- verified portable archive creation;
- protected export with selected-destination review and re-entry confirmation;
- retained-data purge, including its destructive confirmation and status; and
- portable archive restore as an inactive local candidate.

Archive summaries continue to use durable catalogue facts only: display filename,
created date, expiry date, and truthful verification/lifecycle status. The view
states that expiry is checked when the workspace opens or becomes active, not by
a background service. Existing busy, disabled, error, cancel, and incomplete
purge states remain accessible and unchanged.

### Document references

Show only existing aggregate counts for active opportunities: available and
relink-required. Do not show document paths, bookmarks, hashes, filenames, or
open/relink/remove controls. The count refreshes through the existing
workspace-refresh path and therefore remains truthful after relaunch.

### AI & connections

State only the existing MVP fact: the Activity & AI ledger is read-only and
empty; no AI request, cost, model runtime, cloud connection, Gmail, or Calendar
integration is configured. The section introduces no setting, default, consent,
or control that could pre-authorize cloud work or imply availability.

## Data flow and safety invariants

`WorkspaceViewModel` remains the only source for Settings facts and action
entry points. The section switch changes presentation only. Existing action
closures flow from `ContentView` into `SettingsView` and then to the relevant
section; sheets and alerts remain attached to `ContentView`.

The design preserves these invariants:

- a cancel or error path for archive, protected export, purge, or restore does
  not change the current workspace;
- protected export cannot write before destination selection and confirmation;
- restore cannot replace or open the current workspace and yields an inactive
  candidate only;
- recovery-key values never appear in persistent UI, logs, test fixtures, or
  evidence;
- document access metadata never appears in Settings; and
- Settings never represents unavailable AI/cloud/Gmail/Calendar capability as
  configured or enabled.

## Verification design

The eventual task brief and plan must require deterministic fixture coverage
with an injected fixed clock for archive creation, verification, expiry, and
purge states. Settings-specific verification must cover:

- initial default, keyboard, and accessibility navigation across all four
  sections;
- recovery enrolled/not-enrolled, archive catalogue lifecycle, busy/disabled,
  and accessible error states;
- protected-export destination binding, confirmation, error, and cancel with
  no-write/no-current-workspace-change proof;
- inactive restore, restore cancellation, and separate-workspace recovery;
- document-reference availability/relink aggregate counts with no sensitive
  metadata disclosure;
- unavailable/offline AI and connections wording;
- recovery-key redaction from UI, logs, fixtures, and retained evidence; and
- relaunch truthfulness for the selected active local workspace.

Acceptance remains gated by the existing suite, focused Settings UI suite,
signed Debug smoke, independent code review, QA verification, mandatory deep
security/privacy verification, architectural-effect review, Delivery/TPM
release evidence, and product-owner hands-on verification. VD2-08 and its
three accepted accessibility/recovery automation debts are out of scope.

## Non-goals

- New or changed lifecycle, recovery-key, archive, export, restore, expiry,
  purge, document, AI, cloud, Gmail, Calendar, budget, or network behavior.
- New Settings routes, persistent Settings selection, schema/migration changes,
  or changes to `ContentView` ownership.
- Exposure of recovery keys, document paths/bookmarks/hashes/filenames, or
  unconfigured capability.
- Closure of VD2-08 debt or visual/accessibility acceptance for the wider app.
