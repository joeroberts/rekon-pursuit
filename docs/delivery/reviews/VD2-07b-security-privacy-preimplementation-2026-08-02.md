# VD2-07b security/privacy pre-implementation review — 2026-08-02

## Verdict: APPROVE — security/privacy scope gate only

`VD2-07b` is acceptable for the next pre-implementation gate because the
amended brief confines the work to app-owned control presentation and a
content-free test projection. This is **not** an implementation release:
`VD2-07b` remains Backlog until QA/test and Delivery approve the amended RED
contract and release Task 1.

## Scope verification

The brief and current implementation preserve the relevant security and
privacy boundaries.

| Boundary | Verified preservation requirement |
| --- | --- |
| Local persistence, recovery, and key storage | No Core, model, migration, store, audit, recovery/archive/restore/purge, or protected-export behavior is in the Task 2 allowlist. `ContentView` remains the owner of recovery-entry strings, root sheets, protected-export overlay state, and callbacks. A common style may receive presentation state only; it must not receive a model, store, URL, recovery value, persistence object, or callback, and must not add `onChange`, draft, debounce, or save behavior. |
| Recovery-secret handling | Every recovery input must retain root ownership and current empty/error/cancel/confirmation behavior. Test evidence may assert only a fixed control key plus `kind` and semantic state. It must never type, read, attach, log, label, value, screenshot, or otherwise retain a recovery key. No test selector or accessibility projection may derive from the input value. |
| Native macOS file panels | The existing document importer remains the root-owned `.fileImporter` in `ContentView`. The approved work excludes all file-panel styling, wrapping, accessibility changes, callbacks, allowed-content types, cancellation, paths, security-scoped access, and OS-panel automation. Tests may establish only the existing app-side trigger, then stop before interacting with the native panel. |
| Document privacy | Document-reference and CSV chooser assertions must not put a filename, path, hash, MIME type, bookmark, or any native-panel representation in a result attachment, label, value, log, or screenshot. The native-boundary tests must use deterministic app-side state only. |
| AI and network routing | Activity search and all AI-ledger filters remain local, informational filter state. The work introduces no AI request, provider/configuration, network path, ledger record, persisted filter state, or routing change. The existing `AIUsageLedgerFilter` remains a local value filter; test coverage must prove invalid-cost validation, clear/no-results truth, no request or ledger entry, and reset/no-persistence after relaunch. |
| Pipeline native controls | `PipelineNavySearchControl`, stage popup, checkbox, and view-mode control retain their AppKit responder, target/action, delegate, binding, identifier, role, label, and value ownership. Presentation work must not replace or wrap them with a competing focus/accessibility owner. |

## Required security/privacy proof before implementation acceptance

1. Task 1's RED matrix must reach every amended control key and fail only for
   the absent additive projection. Its projection is fixed, non-interactive,
   and content-free: `kind=<text|search|multiline|numeric|picker>` plus an
   applicable semantic state. It must preserve the current native
   identifier/role/label/value and must not include field text, record IDs,
   selected IDs, recovery material, paths, filenames, document metadata, or
   fixture content.
2. Run and retain the amended four top-level UI tests plus the focused
   recovery/root-dialog, CSV/reconciliation native-boundary, Activity/AI
   local-filter, and Pipeline native-role/keyboard tests. Any fixture,
   signing, workflow, persistence/audit, native-panel, disclosure, or
   VD2-08-debt failure is a blocker, never valid RED evidence.
3. Before acceptance, run the brief's retained Contacts, Pipeline, Settings,
   archive, protected-export, and lower-layer regression selectors. Inspect
   the signed result bundles: each selected test executes once, without skip
   or expected failure; labels, values, logs, screenshots, and attachments
   contain neither recovery material nor document metadata.
4. Build the app and UI-test host with the configured Debug signing identity
   and preserve the required signature inspection evidence. Retain the exact
   source inventory, a before/after control-to-selector matrix, per-selector
   RED-to-GREEN result, `git diff --check`, and an explicit attestation that
   native-file-panel code and semantics are unchanged.
5. Keep the Settings keyboard-focus and AI-text semantics, Contacts
   accessibility/recovery automation, and Pipeline Board card-anchor issues
   recorded as VD2-08 debts. This card may not skip, weaken, mask,
   reclassify, or claim them as acceptance evidence.

## Evidence reviewed

- `docs/delivery/task-briefs/VD2-07b-shared-form-control-alignment.md`,
  including the 2026-08-02 amended exhaustive RED matrix.
- `docs/delivery/dashboard-status.json` and `docs/delivery/roadmap.md`:
  `VD2-07b` is Backlog; the AI ledger is local/read-only and Phase 2 routing
  remains out of scope.
- `RekonPursuit/ContentView.swift`: root-owned protected-export/recovery
  state and callbacks, and the existing `.fileImporter` boundary.
- `RekonPursuit/SettingsView.swift`: protected-export dialog receives its
  recovery binding and callbacks from the root owner.
- `RekonPursuit/RekonVisualTheme.swift` and `RekonPursuit/PipelineView.swift`:
  Pipeline native controls retain their current AppKit ownership boundary.
- `RekonPursuit/ContactsView.swift` and `RekonPursuit/AIUsageLedgerFilter.swift`:
  current editor/filter bindings and local validation state.

## Gate handoff

Security/privacy approves the amended bounded scope. Delivery must still hold
implementation until fresh QA/test approval of the amended contract and its
own release check are recorded. Any deviation that touches the preserved
boundaries above requires a new independent security/privacy review before
work proceeds.
