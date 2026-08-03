# VD2-07x Reference-faithful Settings — pre-implementation security/privacy review

**Date:** 2026-08-01
**Role:** Independent security/privacy verifier
**Verdict:** **NEEDS CHANGE** — the proposed filename-only presentation boundary, unavailable-capability copy, and no-change scope are appropriate, but the event design does not prevent an in-flight confirmed export from publishing success after the user cancels. Task 1 must not be released until that race is specified and covered by a deterministic test.

## Scope and basis

Reviewed the controlling design, implementation plan, and Task 1 brief named in the task; the current `WorkspaceViewModel`, `ContentView`, `SettingsView`, protected-export worker/store interfaces, UI-test host, fixture implementation, tests, project settings, and entitlements. This is a plan-gate decision only. No source, test, project, signing, fixture, or entitlement artifact was changed, and no test was run.

## Boundary assessment

| Boundary | Exact evidence | Decision |
| --- | --- | --- |
| Safe success payload | The Task 1 brief requires `ProtectedExportSuccess` to contain exactly `displayFilename` and to be derived from `ProtectedExportReview.displayFilename` only (`docs/delivery/task-briefs/VD2-07x-reference-faithful-settings.md:174-200`). The plan repeats the one-field type and root-only projection (`docs/superpowers/plans/2026-08-01-vd207-reference-faithful-recovery-screen.md:117-137`). This is the necessary reduction because the current review type also holds the destination URL, parent identity, identity digest, and confirmation fingerprint (`RekonPursuitCore/Workspace/ProtectedExportWorker.swift:5-12`). | **Acceptable if implemented exactly.** The event, `SettingsRootModalPresentation`, dialog, fixtures, logs, screenshots, and attachments must receive neither the review nor any field other than the copied display filename. The event must never receive a key, bookmark, fingerprint, checksum, receipt, path, or document data. |
| Default, fixture, and ordinary error states | The brief requires success to be absent in a ready fixture without export and forbids a launch argument, fixture field, or demo control (`...VD2-07x-reference-faithful-settings.md:104-106`); it also requires nil success before review and after destination cancellation or review/write error (`:141-163`). The plan forbids fixture-launch, signing, entitlement, and network changes (`docs/superpowers/plans/2026-08-01-vd207-reference-faithful-recovery-screen.md:11-21`). Current fixtures construct isolated workspaces and do not supply a protected-export success input (`RekonPursuit/RekonVisualTheme.swift:1650-1779`). | **Acceptable in plan, pending implementation evidence.** The named default-absence and error-path assertions are required, but they do not cover cancellation after confirmation has started. |
| Four Settings sections and unavailable capabilities | The design requires aggregate-only Document references and no controls or metadata (`docs/superpowers/specs/2026-08-01-vd207-reference-faithful-recovery-screen-design.md:110-120`) and says AI, cloud, Gmail, Calendar, consent/configuration, and network controls must not be implied or added (`:122-134`). The plan confines those cards to existing aggregate counts and non-actionable offline/not-configured status (`docs/superpowers/plans/2026-08-01-vd207-reference-faithful-recovery-screen.md:204-212`); the brief makes their controls and configuration out of scope (`docs/delivery/task-briefs/VD2-07x-reference-faithful-settings.md:23-34,50-66`). | **Acceptable in plan.** Preserve the proposed panel-scoped no-control and unavailable-copy tests. |
| Signing, entitlement, fixture-launch, and network scope | Task 1 explicitly prohibits project, signing, entitlements, fixture construction/identity, launch parsing, host routing, provider, and network changes (`docs/delivery/task-briefs/VD2-07x-reference-faithful-settings.md:50-66`). The plan repeats that constraint (`docs/superpowers/plans/2026-08-01-vd207-reference-faithful-recovery-screen.md:15-19`) and requires later signed Debug verification. | **No new change is proposed.** The existing sandbox/network entitlement and existing fixture-host behavior are baseline only, not evidence for a scope expansion. |

## Blocking finding — cancellation can race the success event

The proposed Step 6 says to publish the event after `createProtectedExport` returns and only after the existing store-identity guard (`docs/superpowers/plans/2026-08-01-vd207-reference-faithful-recovery-screen.md:117-133`). That guard is insufficient for cancellation.

- `confirmProtectedExport` captures the review, starts an asynchronous write, and on return checks only that the store is still identical before updating state (`RekonPursuit/WorkspaceViewModel.swift:1332-1348`).
- The root export sheet leaves `Cancel` enabled while confirmation is busy (`RekonPursuit/ContentView.swift:195-208`). Its action calls `cancelProtectedExport`, which only clears the review and error; it does not invalidate the in-flight task (`RekonPursuit/WorkspaceViewModel.swift:1357-1360`).
- Thus: confirm; cancel while the write is awaiting; let the already-started write return successfully; the store remains identical; the proposed assignment runs. Task 2 would then display success after cancellation. This violates the design’s rule that cancel/error never produces success (`docs/superpowers/specs/2026-08-01-vd207-reference-faithful-recovery-screen-design.md:77-94`).

## Mandatory correction and checks

1. Define an opaque export-attempt/operation token owned by `WorkspaceViewModel`. A confirmation captures its token; `cancelProtectedExport`, a new review, any terminal failure, and teardown/workspace replacement invalidate it. Publish the success event only if the captured token is still current as well as the store-identity guard still passing. Do not pass the token, review, URL, or sensitive review fields into Settings.
2. Add a deterministic gated-write unit test: complete a valid review, begin confirmation, wait until the write is in flight, cancel through the existing model path, release the write, and assert `protectedExportSuccess == nil`, no root success presentation, and unchanged active-workspace identifiers. This test must not assert a changed lower-layer write/cancellation contract or log a key.
3. Add that test to the signed Task 1 and Task 2 matrices. It must pass once with no skip or expected-failure classification; it is not an allowed visual RED.
4. At implementation review, inspect the isolated diff to prove the success value and root modal contain only the copied display filename; inspect all retained result attachments for the forbidden sensitive fields; and verify no fixture-host, launch parser, project signing, entitlement, or network hunk is present.

## Release status

**Do not release VD2-07x Task 1.** Reissue this security/privacy gate after the token rule and deterministic in-flight-cancellation proof are added to the controlling brief and plan.
