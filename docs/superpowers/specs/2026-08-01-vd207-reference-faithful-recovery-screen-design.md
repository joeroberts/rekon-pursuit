# VD2-07x — Reference-faithful Settings screen design

**Date:** 2026-08-01
**Status:** Product-owner approved; amended 2026-08-01 after visual owner
feedback. This document supersedes the visual composition portions of
`2026-08-01-vd207-settings-information-architecture-design.md`.
**Controlling references:**

- `/Users/jroberts/Downloads/Generated image 3 (1).png`
- `/Users/jroberts/Downloads/Codex Image Aug 1, 2026, 03_08_32 PM.png`
- `/Users/jroberts/Downloads/Codex Image Aug 1, 2026, 03_09_00 PM.png`
- `/Users/jroberts/Downloads/Codex Image Aug 1, 2026, 03_09_49 PM.png`
- `/Users/jroberts/Downloads/Codex Image Aug 1, 2026, 03_10_50 PM.png`

## Purpose and scope

The Settings screen must look and feel like the approved dark desktop reference,
not like a generic heading, text-button, and panel stack. The references govern
all four local sections: their common tab treatment, hero/status composition,
cards, disabled/unavailable treatment, and the Recovery protected-export
success dialog.

The existing global app rail remains visible and unchanged. The four Settings
sections remain local, non-persisted presentation state. This is a visual and
presentation re-composition only: no recovery, archive, export, purge, restore,
workspace, document, AI, cloud, signing, entitlement, fixture, or persistence
behavior may change.

## Approved desktop composition

### Shell and local navigation

- Preserve the existing five-destination global rail at the left, including its
  active cyan Settings treatment; do not replace it with the Settings sections.
- Preserve the app title bar above the content.
- The content begins with a large, left-aligned `Settings` heading.
- Directly beneath it, render the four Settings-local sections as a wide,
  single-row icon-and-label selector: Workspace, Recovery & archives, Document
  references, and AI & connections.
- Each selector uses a semantic SF Symbol, a generous hit target, and the same
  cool-gray text family as the reference. At wide width, the selected Recovery
  & archives item uses cyan icon/text plus a cyan bottom rule that spans its
  tab cell; the whole selector has a subdued bottom divider.
- At compact width, retain the four destinations and semantic focus behavior in
  a vertical layout. Do **not** carry the wide cyan bottom rule into this
  layout: it looks detached from a vertical selector. Instead, the selected
  compact row uses a restrained cyan-tinted rounded selection surface plus
  cyan icon/text; unselected rows stay transparent with cool-gray icon/text.
  The row remains a complete labeled selector with the same selected,
  non-selected, keyboard, pointer, and accessibility semantics as wide mode.
  Never hide a section, replace local selection with a global route, or
  persist it.

### Recovery & archives overview

The selected Recovery section is a deliberate dashboard, not a vertical list of
settings controls:

1. A large outlined overview card leads the page. It contains an emerald
   circular shield/check visual on the left, a clear recovery-state headline,
   and concise status/recovery facts. Copy derives from existing durable state:
   it must truthfully distinguish not enrolled, enrolled with no archive, and
   enrolled with archive catalogue facts.
2. A second outlined archive-detail card presents the existing safe archive
   catalogue facts in a calm two-column reading order: created date, expiry,
   and verification/lifecycle state. It never shows a recovery key, checksum,
   signing fingerprint, bookmark, raw filesystem path, or document metadata.
3. A three-column action-card row presents the existing actions with large,
   purposeful line icons: create portable archive, manage retained archive data,
   and restore portable archive. The cards remain buttons, retain current
   disabled/busy/error/cancel semantics, and use the exact pre-existing action
   closures. If the viewport is too narrow, they reflow without becoming an
   unlabelled icon grid.
4. Protected export remains an existing recovery action. It is visually grouped
   with archive facts/actions and continues through the existing destination
   selection and review flow. It must never write before the real review and
   confirmation operations complete.

The page uses the established navy-black shell, thin slate outlines, restrained
lavender secondary text, cyan selection, and emerald verified/success accents.
Spacing is intentionally generous, cards have modest rounded corners, and the
content reads as one recovery workspace rather than as disconnected widgets.

### Protected-export success dialog

After—and only after—the existing protected-export flow has completed a real
successful write, `ContentView` presents a root-owned success dialog over the
Recovery screen. It is not a fixture default, demo switch, or simulated success
state.

- The dialog must closely follow the supplied reference rather than resemble a
  generic macOS alert: center a dark, elevated, rounded panel over a subdued
  Recovery background; place an emerald circular check at the top; then the
  `Protected copy exported` heading and succinct confirmation copy. Use the
  reference's spacious, centered hierarchy and a single, deliberate panel
  outline/shadow.
- Beneath the confirmation, show a bordered two-row export-facts group. Its
  left labels are `Exported file` and `Saved to`; its values are respectively
  the existing display filename and exactly `Selected local folder`. The rows
  have a quiet divider between them. It must not reveal an absolute path,
  bookmark, recovery key, key-derived material, or any document metadata.
- The existing recovery-key reminder follows the facts group with a small
  emerald lock/check cue and no displayed key.
- The single `Done` action is full panel width and uses the reference's
  blue-to-violet primary treatment. It only dismisses the success presentation;
  it does not mutate the active workspace, rerun the export, or alter recovery
  state.
- Existing export error and cancellation behavior remain root-owned and visible
  through the current presentation flow; a cancel/error never produces success.

### Workspace visual contract

The Workspace tab follows the same hero-plus-cards pattern:

1. A large outlined hero presents a cyan folder symbol, `Local workspace`,
   `Workspace status` / `Active`, and `Storage` / `Local only`. These are
   current local facts, not a new workspace-status system.
2. An outlined `Workspace recovery` card explains the existing preserved
   workspace safety contract: returning does not modify the active workspace.
3. The final return card presents the real current state. When no separate
   workspace is active, it is visibly disabled, says no preserved workspace is
   available, and has no action. When a separate workspace is active, it
   exposes the existing return-to-preserved-workspace action and nothing else.

### Document references visual contract

The Document references tab stays aggregate-only while matching the reference:

1. Its hero uses a cyan document symbol, `Document references`, and the
   statement that it tracks availability without exposing file details.
2. Two hero facts and two outlined count cards show existing `Available` and
   `Needs relinking` totals. Cyan denotes available; amber denotes relinking.
3. A muted information card states that document names and locations stay
   private. No document rows, paths, bookmarks, hashes, MIME types, filenames,
   open/relink/remove buttons, or controls are rendered.

### AI & connections visual contract

The AI & connections tab is a truthful unavailable-capability status surface:

1. Its hero uses the cool-violet chain symbol, `AI & connections`, and states
   that no cloud services are connected. The facts are `AI activity` / `No
   activity recorded` and `Connection status` / `Offline`.
2. Three outlined informational cards describe `AI assistant` / `Not
   configured`, `Email & calendar` / `Not connected`, and `Cloud sync` / `Not
   configured`. They are status cards, not links or setup controls.
3. A muted information card says that the workspace remains local and private.
   No AI, cloud, Gmail, Calendar, budget, consent, configuration, or network
   control may be implied or introduced.

## Ownership and data boundary

`ContentView` remains owner of the workspace model, global route, all recovery
and export sheets/alerts, destination selection, the new success-dialog binding,
and every action dispatch. `SettingsView` owns only its local selected section
and renders display-safe values plus callbacks. It may not own a model, file
URL, recovery key, persistent selector preference, or success-state invention.

The presentation boundary remains deliberately narrow:

- archive detail receives safe display values only;
- action cards receive the already-existing action closures and disabled/busy
  facts only; and
- success presentation receives a boolean, safe display filename, and dismiss
  callback from the root.

## Verification requirements

The revised test-first task brief must prove all of the following in the signed
Debug app and deterministic fixture host:

- global rail stays present while Settings-local icon tabs are keyboard
  reachable, use selected/non-selected semantics, default to Recovery, and
  reflow at compact width;
- Recovery renders the overview, archive detail, and three truthful action
  cards without exposing sensitive archive/document data;
- Workspace, Document references, and AI & connections each render the
  matching hero/card composition, use the approved accent/status colors paired
  with text, preserve tab keyboard semantics, and do not invent capabilities;
- document counts remain aggregate-only and the unavailable AI cards contain
  no actionable descendant controls;
- current lower-layer archive, purge, restore, separate-workspace, and export
  safety contracts still run once, pass, and have no skip;
- a success dialog is impossible before confirmation, cancellation, or error;
  after a successful test-controlled export it shows only safe values and Done
  dismisses without changing the active workspace;
- error text remains accessible; and
- wide/compact rendered screenshots are compared against the approved
  composition for hierarchy, active-tab treatment, card layout, and dialog
  hierarchy. The review includes a wide Recovery capture and a compact capture
  with one clearly selected local-section row; the compact capture proves the
  rounded cyan row treatment and the absence of a detached underline. The
  real-export dialog capture proves the centered check → heading → confirmation
  → two-row facts → reminder → full-width Done hierarchy. Each capture contains
  only the app window—never desktop, Finder, another app, a chooser, or other
  surrounding window chrome—and contains no recovery key or document metadata.

## Explicit non-goals

- Making success the default Recovery screen or adding a test-only success
  switch.
- Changing export destination review, writing, recovery-key verification,
  archive retention/expiry, restore/purge behavior, data models, storage,
  migrations, fixtures, signing, or entitlements.
- Exposing paths, keys, document names, hashes, bookmarks, checksums, or any
  unavailable AI/cloud/Gmail/Calendar capability.
- Absorbing VD2-08 or its accepted accessibility/recovery automation debts.
