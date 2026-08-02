# VD2-07x protected-export dialog unification — Security/privacy gate

**Date:** 2026-08-02
**Role:** Fresh independent Security/privacy verifier
**Verdict:** **ACCEPT — release only the approved, visual-only implementation.**

## Scope and method

This is a pre-implementation static gate. I reviewed the approved dialog
unification design and implementation plan, plus the current protected-export
presentation and state seams in `ContentView.swift`, `SettingsView.swift`, and
`WorkspaceViewModel.swift`. I also checked the existing focused UI/model test
contracts for safe presentation, error continuity, cancellation, and
real-success behavior. No production or test code was changed, and no tests
were run by this gate.

## Evidence and assessment

| Security/privacy property | Evidence | Gate assessment |
| --- | --- | --- |
| Recovery-key boundary | The root currently owns the re-entry string and clears it on cancellation, confirmed action, review transition, and verified success. The approved dialog contract permits only that existing `Binding<String>` for its text field; it has no model, store, receipt, persistence, or logging dependency. | Acceptable if the binding remains the sole key-related input and no text, accessibility value, test attachment, diagnostic, or persistence path is added. |
| Destination and document-data disclosure | `ProtectedExportReview` contains the existing destination URL, but its safe `displayFilename` projection is separate. The plan passes only that filename through `.confirmation(displayFilename:)` and specifies fixed local-folder and active-data labels. The current success event likewise contains only `displayFilename`, and existing model coverage asserts it has no path separator. | Acceptable if the dialog receives neither the review nor any URL, bookmark, document reference, metadata, hash, fingerprint, receipt, export bytes, database object, or store identity. |
| Native-panel/filesystem authority | The sole protected-export `NSSavePanel` construction and URL return path are currently private to `WorkspaceViewModel`; `reviewProtectedExport` invokes it before the existing worker review. The approved `ContentView` action keeps that same call and the plan expressly excludes panel, worker, entitlement, scope, and persistence changes. | Acceptable if no panel configuration, security-scoped access, entitlement, URL lifetime, file operation, or retry/cleanup behavior changes. The custom overlay must remain behind the unchanged native panel after the existing action is invoked. |
| Error safety and continuity | The model maps worker/store errors through controlled messages and retains the review for correction where current behavior does. The plan renders the unchanged error immediately above the form, keeps the flow open, and its focused UI journey supplies no key or destination. | Acceptable if error copy remains controlled and non-interpolating; it must never expose a path, key material, export content, filesystem diagnostics, or document metadata. |
| Truthful success | `protectedExportSuccess` is set only after the existing create closure returns successfully, and only after the operation-token and store-identity checks; it carries only the filename. The root already dismisses the in-progress state and clears the re-entry string on this event. Existing model coverage requires no success event for each non-success branch. | Acceptable if the success dialog remains gated solely by this event, with no fixture default, launch argument, demo control, test-only success branch, or early presentation. |
| Persistence and audit boundary | The approved change is confined to root presentation, a presentation-only Settings component, a focused invalid-key UI test, and delivery evidence. It excludes ViewModel, worker, store, activity, database, and schema behavior. | Acceptable if the final diff adds no persistence, activity/audit record, log, attachment, preference, or serialization of protected-export inputs or outputs. |

## Required implementation boundary

The fresh implementer is released only for the exact approved slice. The new
dialog may accept: its entry/confirmation mode; the filename-only display
projection; the existing root-owned recovery-key binding; controlled error
text; busy state; and root-owned cancel/primary closures. It must not receive
the `ProtectedExportReview`, a URL, recovery-key value outside the binding,
receipt, store, workspace payload, document data or metadata, persistence
dependency, or native-panel authority.

`ContentView` must preserve the same three ViewModel actions and key-clearing
rules, keep exactly one protected-export overlay visible, and show the existing
success dialog only after the verified-success event. The `NSSavePanel`,
security-scoped access, export worker, local storage, activity evidence,
entitlements, and test fixtures are out of bounds.

## Release condition

Release a fresh implementer only after the other independent pre-implementation
gates also release the task. Before delivery acceptance, a fresh security/privacy
verifier must inspect the exact implementation diff and confirm all of the
following:

1. The dialog initializer and every call site contain only the approved safe
   values and closures; the URL-bearing review is reduced to its filename before
   crossing into the presentation component.
2. No ViewModel, worker, store, native-panel, sandbox/scope, entitlement,
   persistence, activity/audit, logging, attachment, fixture, or launch-path
   change exists.
3. The focused UI test exercises only the invalid-key route, creates no
   destination, and records no sensitive value; the selected model protections
   still prove controlled-error retention, cancellation safety, and
   verified-write-only success.
4. The signed owner-native run proves the unchanged native selection path and
   real verified success using only redacted outcome evidence. It must not
   retain or attach recovery material, raw paths, export content, database data,
   or document metadata.

Any deviation from these conditions is **NEEDS CHANGE** and requires a fresh
security/privacy review before release.
