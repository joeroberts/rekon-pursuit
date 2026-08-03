# VD2-07 Settings information architecture — pre-implementation security/privacy review

**Date:** 2026-08-01  
**Role:** Independent security/privacy verifier  
**Verdict:** **NEEDS CHANGE** — the intended presentation boundary is sound, but the released test commands do not execute all of the safety evidence that the approved design and task brief require.

## Scope and review basis

Reviewed the design-only commits `efe1de6` and `ec0b5ce`, the current
Settings/route/view-model implementation, the recovery/archive/export/restore
and document-summary paths, the deterministic UI-test host, and the named
test sources. `git show --name-status` confirms that the two reviewed commits
add only the design, task brief, and implementation plan; they contain no
production implementation. The current Settings implementation is still the
private `SettingsView` in `RekonPursuit/ContentView.swift`.

This is a pre-implementation review. It is not test-result evidence for a
future extraction, and it does not approve a source diff, signing change, or
delivery transition.

## Evidence and findings

| High-risk boundary | Evidence reviewed | Finding |
| --- | --- | --- |
| Recovery-key ownership and redaction | The approved design keeps recovery-key state, picker state, sheets, alerts, and cancel behavior in `ContentView` (`docs/superpowers/specs/2026-08-01-vd207-settings-information-architecture-design.md:34-55,96-114`). The brief makes `SettingsView` presentation-only and limits its callback surface (`docs/delivery/task-briefs/VD2-07-settings-information-architecture.md:23-59`). The planned `SettingsRecoveryPresentation` contains booleans, display text, and archive summaries—not a key—and requires the original sheet bodies and bindings to move verbatim (`docs/superpowers/plans/2026-08-01-vd207-settings-information-architecture.md:277-400`). The current UI shows the key only inside the existing enrollment sheet and clears the UI fields on dismissal/cancel (`RekonPursuit/ContentView.swift:946-976`). | **Design boundary accepted.** A post-Task-2 reviewer must still compare every moved binding, including dismissal resets, because moving these states to `ContentView` changes their SwiftUI lifetime. |
| Protected-export destination binding and no-write behavior | The unchanged worker binds the reviewed filename and parent identity before create, rechecks both identity and source revision before any output write, and uses exclusive output creation (`RekonPursuitCore/Workspace/ProtectedExportWorker.swift:54-105,180-205`). Existing tests prove parent binding, source-change no-file, and existing-target no-overwrite (`RekonPursuitCoreTests/ProtectedExportTests.swift:52-105`). The proposed UI has no direct worker/store access and routes existing actions through `ContentView` (`docs/superpowers/plans/2026-08-01-vd207-settings-information-architecture.md:375-400`). | **Implementation boundary accepted; release evidence incomplete.** The approved design expressly requires destination binding plus confirmation/error/cancel no-write proof (`docs/superpowers/specs/2026-08-01-vd207-settings-information-architecture-design.md:103-109,126-133`), but the Task 1 and Task 2 commands run only the source-change test and a view-model existing-target error test. They omit `testReviewBindsDestinationParentIdentity` and `testExistingTargetIsRejectedWithoutOverwritingIt`; no currently named test proves `cancelProtectedExport()` leaves no output/current-workspace mutation. |
| Purge destructive boundary | The existing Settings control is gated by enrollment, catalogue presence, and busy state, then presents a destructive re-entry confirmation (`RekonPursuit/ContentView.swift:881-901,1029-1054`). The core purge path scopes itself to managed archives, writes/verifies a replacement before predecessor removal, retains durable incomplete/cancel state, and explicitly excludes external archives (`RekonPursuitCore/Workspace/WorkspaceStore.swift:1036-1239`). Existing tests cover deleted-material removal and reject an incorrect key before a job or lease is written (`RekonPursuitCoreTests/PortableArchiveTests.swift:1959-2010,2219-2240`). | **Implementation boundary accepted; release evidence incomplete.** Both tests are named as required in the brief (`docs/delivery/task-briefs/VD2-07-settings-information-architecture.md:82-88`), yet only the incorrect-key test is included in the released Task 1/2 commands (`docs/superpowers/plans/2026-08-01-vd207-settings-information-architecture.md:417-432`). The destructive projection/replacement test is omitted. |
| Restore isolation and separate-workspace invariant | Existing restore verifies before confirmation and returns an inactive candidate (`RekonPursuit/WorkspaceViewModel.swift:1412-1525`). The restore service never reads or writes the active-workspace selector and creates a separately keyed candidate (`RekonPursuitCore/Workspace/PortableArchiveRestore.swift:309-371,450-489`). Existing tests prove source preservation, inactive restore properties, cancellation/scope release, and separate-workspace relaunch/return behavior (`RekonPursuitCoreTests/PortableArchiveTests.swift:1215-1295`; `RekonPursuitTests/WorkspaceViewModelTests.swift:225-276,508-547,1101-1208`). | **Implementation boundary accepted; release evidence incomplete.** The brief requires the inactive-restore and separate-workspace tests, but the Task 1/2 commands omit `testVerifiedArchiveRestoresIntoANewInactiveWorkspaceWithoutChangingSource`, `testRelaunchPrefersSelectedSeparateWorkspaceAndRetainsOpportunity`, and `testReturnToPreservedRecoveryClosesSeparateStoreAndChangesOnlySelector`. |
| Document metadata non-disclosure | `WorkspaceStore.documentReferenceSummary()` returns only the two aggregate availability counts (`RekonPursuitCore/Workspace/WorkspaceStore.swift:1336-1357`). The plan passes only `DocumentReferenceSummary` and prohibits the document object, path, bookmark, hash, filename, byte count, and document actions (`docs/delivery/task-briefs/VD2-07-settings-information-architecture.md:47-59`; `docs/superpowers/plans/2026-08-01-vd207-settings-information-architecture.md:311-373`). The proposed fixture test asserts aggregate text and absence of seeded filename/hash/relink controls. | **Accepted for the planned interface, contingent on post-implementation source review.** No document-reference object is authorized to cross into Settings. |
| AI, cloud, Gmail, and Calendar capability | The design requires factual unavailable wording and prohibits any setting, default, consent, or control that could pre-authorize service use (`docs/superpowers/specs/2026-08-01-vd207-settings-information-architecture-design.md:89-94`). The planned AI section receives no configuration object and contains only the factual static availability label (`docs/superpowers/plans/2026-08-01-vd207-settings-information-architecture.md:358-373`). The file allowlist prohibits entitlement, signing, network, route, and model changes (`docs/delivery/task-briefs/VD2-07-settings-information-architecture.md:21-28`). | **Accepted.** No new provider, credential, consent, or network entry point is planned. Existing unrelated network entitlement/capabilities are not re-approved by this review. |
| Logs, fixtures, screenshots, and retained evidence | The test host requires an explicit fixture and seeds only a UUID-qualified temporary encrypted workspace (`RekonPursuitUITestHost/BootstrapApp.swift:55-73`; `RekonPursuit/RekonVisualTheme.swift:1343-1521,1573-1669`). The design/brief forbid user recovery-key values in UI, logs, fixture source, result attachments, screenshots, and evidence (`docs/superpowers/specs/2026-08-01-vd207-settings-information-architecture-design.md:103-114`; `docs/delivery/task-briefs/VD2-07-settings-information-architecture.md:71-80`). The four proposed UI tests deliberately avoid recovery-key sheets and screenshots. Static review found no logging API use in the affected Settings, view-model, fixture-host, export, and restore paths. | **Accepted as a plan constraint.** The post-Task-2 verifier must inspect generated result attachments and the exact test diff rather than infer redaction from the plan. |
| Shared `ContentView` sheet and route regression | The present global rail owns the sole `.settings` route (`RekonPursuit/AppShellView.swift:3-102,189-239`; `RekonPursuit/ContentView.swift:134-161`). The plan keeps the local selector as private `@State`, mandates no global route or persisted selection, and requires the exact sheet/alert calls to remain `ContentView`-owned (`docs/superpowers/plans/2026-08-01-vd207-settings-information-architecture.md:11-22,326-356,375-400`). | **Design boundary accepted.** The existing sheet/alert bodies are high-risk shared state; Task 2 must be independently diff-reviewed for one-and-only-one attachment, unchanged binding setters, and cancellation cleanup. The current proposed UI tests cover section/rail selection but do not exercise every moved sheet cancellation path. |

## Required correction before Task 1 release

Revise the brief/plan and its exact Task 1 and Task 2 commands so the executed
evidence matches the explicitly required matrix. At minimum, the command set
must include the already-existing tests for destination-parent binding and
existing-target no-overwrite; retained-data purge projection/replacement; an
inactive restore that preserves the source; and separate-workspace
relaunch/return. Add a focused cancellation/no-write proof for protected export
after a review exists, or explicitly identify an existing test that proves that
exact path. The revised evidence must also verify the moved `ContentView`
sheet/alert cancellation bindings without entering a fixture or attachment
containing a user recovery key.

The Task 1/Task 2 commands currently contradict the brief's required evidence
list: compare `docs/delivery/task-briefs/VD2-07-settings-information-architecture.md:82-88`
with `docs/superpowers/plans/2026-08-01-vd207-settings-information-architecture.md:207-250`
and `414-451`. This is a verification gap, not authorization to modify core
recovery behavior or test-host fixture transport.

## Residual risk after correction

The extraction deliberately moves modal state from a route-local view to the
root `ContentView`. Even with identical action calls, that can alter dismissal
and route-lifetime behavior. A future implementation must therefore be checked
against the exact pre-extraction sheet/alert bindings in
`RekonPursuit/ContentView.swift:946-1125`, while the signed focused suite
demonstrates that cancellation, error, and busy paths leave the active
workspace unchanged. A protected-export write failure can still report that an
output may remain; that is the existing explicit error contract, not a new
Settings behavior (`RekonPursuitCore/Workspace/ProtectedExportWorker.swift:30-43,99-125`).

## Release status

**No Task 1 implementation is released by this report.** This NEEDS CHANGE
decision records only the pre-implementation security/privacy gate result.
Task 1 remains blocked pending the verification-plan correction, a fresh
security/privacy decision, the other required independent approvals, and a
dependency-safe Delivery release.
