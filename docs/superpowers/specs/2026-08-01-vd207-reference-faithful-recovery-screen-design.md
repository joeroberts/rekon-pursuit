# VD2-07x — Reference-faithful Recovery & archives design

**Date:** 2026-08-01
**Status:** Product-owner approved. This document supersedes the visual
composition portions of `2026-08-01-vd207-settings-information-architecture-design.md`.
**Controlling reference:** `/Users/jroberts/Downloads/Generated image 3 (1).png`

## Purpose and scope

The Settings screen must look and feel like the approved dark desktop reference,
not like a generic heading, text-button, and panel stack. The reference governs
the entire **Recovery & archives** surface: its hierarchical composition,
tab treatment, status overview, archive/action cards, and protected-export
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
  cool-gray text family as the reference. The selected Recovery & archives
  item uses cyan icon/text plus a cyan bottom rule that spans its tab cell; the
  whole selector has a subdued bottom divider.
- At compact width, retain the four destinations and semantic focus behavior in
  a vertical layout. Never hide a section, replace local selection with a global
  route, or persist it.

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

- The dialog uses a dark elevated rounded panel, an emerald success check,
  `Protected copy exported` heading, and succinct confirmation copy.
- It shows only safe, truthful export facts: the existing display filename and
  a generic selected-local-folder label. It must not reveal an absolute path,
  bookmark, recovery key, key-derived material, or any document metadata.
- The existing recovery-key reminder stays visible without displaying the key.
- The single `Done` action uses the blue-to-violet primary treatment from the
  reference and only dismisses the success presentation. It does not mutate the
  active workspace, rerun the export, or alter recovery state.
- Existing export error and cancellation behavior remain root-owned and visible
  through the current presentation flow; a cancel/error never produces success.

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
- current lower-layer archive, purge, restore, separate-workspace, and export
  safety contracts still run once, pass, and have no skip;
- a success dialog is impossible before confirmation, cancellation, or error;
  after a successful test-controlled export it shows only safe values and Done
  dismisses without changing the active workspace;
- error text remains accessible; and
- wide/compact rendered screenshots are compared against the approved
  composition for hierarchy, active-tab treatment, card layout, and dialog
  hierarchy. Screenshot evidence must contain no recovery key or document
  metadata.

## Explicit non-goals

- Making success the default Recovery screen or adding a test-only success
  switch.
- Changing export destination review, writing, recovery-key verification,
  archive retention/expiry, restore/purge behavior, data models, storage,
  migrations, fixtures, signing, or entitlements.
- Exposing paths, keys, document names, hashes, bookmarks, checksums, or any
  unavailable AI/cloud/Gmail/Calendar capability.
- Absorbing VD2-08 or its accepted accessibility/recovery automation debts.
