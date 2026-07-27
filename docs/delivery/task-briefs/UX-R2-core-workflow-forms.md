# UX-R2 — Core workflow forms

**State:** In progress — UX-R2-A and UX-R2-B accepted; UX-R2-C is next up and not yet started
**Depends on:** Accepted `UX-R1`  
**Blocks:** `RP-R6` durable document references

## Outcome

Make the three high-frequency local workflows coherent and usable without changing their product boundaries: Pipeline-owned Add opportunity capture, Contacts capture and employer context, and Pipeline-owned Import CSV.

## Approved scope

### Add opportunity and overview

- Use multiline, expanding job-description and notes editors.
- Accept a typed job URL only when it is an absolute `http` or `https` URL with a non-empty host. HTTP saves with a warning; malformed/hostless URLs reject save and leave the record unchanged. Preserve imported historical non-HTTPS URLs but warn.
- Represent compensation as USD minimum/maximum plus pay period and format values as dollars. Each populated amount is non-negative and minimum cannot exceed maximum; incomplete ranges remain permitted. Invalid input rejects save and leaves the record unchanged. Preserve existing legacy compensation text until edited; do not infer details from a job URL.
- Keep location free text paired with the existing work-arrangement picker; do not claim offline geographic validation.
- Replace the free-form next-action entry with a small action-type picker and an Other text field. Existing imported/custom action text remains editable as Other.
- When a new opportunity is saved with no selected applied date, store the creation date as its application date. An explicit date overrides that default.
- Remove workspace/count/activity/status-footer clutter from capture and overview screens. Do not fetch or parse job URLs.

### Contacts

- Validate email syntax only. A typed profile URL must be an absolute `http` or `https` URL with a non-empty host; HTTP warns and malformed/hostless URLs reject save without mutating the contact. No deliverability check or provider restriction.
- Replace free-text employer entry with a searchable local canonical-employer picker sourced from tracked opportunity companies, plus Add new employer.
- Expose that employer's tracked opportunities after save and require explicit contact-to-opportunity link/unlink actions. Never silently create links.
- Keep relationship context and notes as separate compact multiline fields with user-triggered expansion. Do not add a category picker: the product owner’s durable UX-D8 decision treats the context itself as the reusable free-text relationship record.

### CSV import

- Retain deterministic local import and duplicate decisions. Present clear Choose file, Map columns, Review rows/duplicates, and Completion steps.
- Provide Cancel, Back/Start over, and Done actions that clear only transient preview state; completed reports remain durable.
- Use consistent section headings and primary/secondary Rekon controls.
- Completion shows totals and View imported opportunities in Pipeline. Inline exceptions are invalid, duplicate, skipped, updated, or failed rows. A secondary detailed report identifies title/company, never routine Row N created actions.

## Boundaries

- Local-only: no URL fetching/parsing, networking, AI, Gmail, Calendar, document handling, employer research, preferences redesign, or new dependency.
- Preserve R3 mapping, validation, field-selected update, atomic commit, durable report, no raw-source retention, and no-silent-overwrite contracts. The completed report may persist normalized title/company display values for every row, including invalid or skipped rows; it must not retain raw cells or the source path.
- Preserve R2 history/activity semantics and legacy values. A migration is allowed only when structured compensation/action fields cannot be represented compatibly; it must be additive and retain legacy text. CSV compensation maps to legacy compatibility text and clears structured amounts/pay period when that selected field changes, because untrusted free-text pay strings are not parsed. CSV next actions map to `Other` with the imported text as its custom value; reminder titles retain that exact custom text.
- Keep UX-R1 overview/history/reconciliation/compact-documents navigation intact. `RP-R6` owns bookmarks, open, and relink.

## Implementation slices

### UX-R2-A — opportunity form and compatibility data

**Likely files:** `WorkspaceModels.swift`, `WorkspaceStore.swift`, `WorkspaceViewModel.swift`, `ContentView.swift`, focused model/store tests.

1. Write focused tests for malformed/hostless URL rejection, HTTP warning, creation-date default, non-negative/minimum-not-greater-than-maximum compensation rejection, legacy compensation/action preservation, and structured save/edit with no unintended history change.
2. Add the smallest additive representation needed for structured compensation and action type/custom text; migrate old rows without data loss.
3. Replace only Add/Overview controls and validation copy using native SwiftUI and existing Rekon tokens.

### UX-R2-B — contacts and employer relationship flow

**Likely files:** `WorkspaceModels.swift`, `WorkspaceStore.swift`, `WorkspaceViewModel.swift`, `ContentView.swift`, focused model/store tests.

1. Test email/profile validation, employer suggestions, exact normalized employer matching, visible employer opportunities after save, no implicit link, explicit link/unlink, and multiline relationship-context retention.
2. Add persistence only if the existing schema cannot express the required explicit links; derive employer suggestions locally from opportunity companies.
3. Implement searchable picker, Add new employer, explicit links, and expandable context/note editors.

### UX-R2-C — staged CSV presentation and report completion

**Likely files:** `ContentView.swift`, `WorkspaceViewModel.swift`, existing CSV-focused tests.

1. Test that cancel/restart clears preview but not a completed report; summaries retain exception totals, imported-record selection, and title/company identity for invalid, skipped, and duplicate rows after relaunch.
2. Add the smallest additive completed-report title/company fields needed for that durable display, without retaining raw source cells or paths.
3. Replace the single long form with step-local controls: Back, Cancel, Start over, Done, View imported opportunities, and detailed report. Do not change importer parsing, matching, decisions, or transaction logic unless a separate defect is proven.

## Acceptance evidence

- Add/edit/relaunch preserves multiline description, URL behavior, dollar compensation, location/work arrangement, creation-date default, typed action, and legacy data.
- Contact save supports local validation, selected/new employer, expandable context/notes, visible normalized employer opportunities, and only explicit opportunity links.
- CSV supports choose, map, validate, review, cancel/restart, import, comprehensible completion, and durable report reopening.
- Focused local tests cover these data-risk edges; a Debug macOS build and one product-owner hands-on workflow pass. No CI or coverage gate is added.

## Release rule

Planning, Architect, QA, TPM, and Delivery independently approve this brief before implementation. Release only `UX-R2-A`; after its acceptance release B, after B acceptance release C, and accept UX-R2 only after C plus product-owner hands-on verification. Do not begin `RP-R6` until full UX-R2 acceptance.
