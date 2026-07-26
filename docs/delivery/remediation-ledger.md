# Rekon Pursuit — MVP remediation ledger

**Status:** The current evidence-backed operational state is: `RP-R0`,
`RP-R1a`, `RP-R1b`, `RP-R2`, `RP-R3`, `RP-R4`, and `RP-R5` Accepted; `UX-R1`
is In progress on **Task 1 only**: a user-selected read/write external-workspace
bookmark and recovery slice; `UX-R2`, `RP-R6`, and
`RP-R7a`–`RP-R10` are Backlog. No successor implementation is released.

**Authority:** [dashboard-status.json](dashboard-status.json) is the canonical
machine-readable operational view for the current remediation queue. This
ledger is its detailed audit/evidence record; meaningful future transitions
must update both records together and regenerate the local dashboard. It
supersedes “MVP shipped” language in the roadmap and candidate handoff. The
PRD, architecture specification, ADR-001, and approved mockups remain
controlling requirements.

## Dashboard operational-baseline decision

**Date:** 2026-07-25

**Decision owner:** Product owner, recorded by Delivery Manager

**Decision:** The initial dashboard seed was superseded by the product owner
on 2026-07-25 because it incorrectly placed accepted R2 back into hands-on
verification. The current status sequence above restores the accepted R2
evidence and makes R3 the next eligible remediation task. From this decision
forward, `dashboard-status.json` governs each current task status; this ledger
records the reason, evidence, and release condition for the same transition.
The only normal path is Backlog → Next up → In progress → Accepted. Blocked
is reserved for a genuine material impediment requiring intervention, not
ordinary sequencing.

### RP-DASH-001 — Local delivery dashboard

| Role | Decision | Evidence / boundary |
| --- | --- | --- |
| Planning | Approved | The task brief defines one operational JSON source, exact lane semantics, a static local projection, and the coupled JSON/ledger update contract. |
| Architect | Approved | The static renderer embeds source state for `file://`, adds no network or app boundary, and restricts evidence links to repository-local paths. |
| TPM | Approved | The operational-baseline reset preserves prior records as history, keeps R2/R3 sequencing explicit, and does not alter the macOS product roadmap. |
| QA | Approved | Focused checks cover the source contract, deterministic generated page, 30-second refresh marker, required lanes/counts/cards, attention semantics, and local evidence links. |
| Code Reviewer | Approved after P1 remediation | URL-encoded traversal, separators, and control characters are rejected before local-link resolution; generated attention items use valid list markup. |
| Delivery Manager | **Accepted — RP-DASH-001 complete** | Independent plan, implementation, and QA gates approved. The local dashboard is generated from `dashboard-status.json`; this ledger remains the detailed evidence record. The seeded operational queue is verified, and future meaningful transitions update JSON, ledger, and generated HTML together. |
| Product owner | **Corrected operational state** | The initial dashboard seed incorrectly retriggered R2 verification despite accepted evidence. R2 remains Accepted; R3 is Next up; the attention queue is empty. |
| Product owner | **Released R3** | R3 moved from Next up to In progress. Scope is limited to the approved core CSV mapping/import workflow; no successor is released. |

## Verified gaps

| Requirement | Current verified state | Remediation task |
| --- | --- | --- |
| First-run workspace | Create action is hidden off the default page; a dangling-key/no-database state is currently reported as unavailable and has no recovery path. | `RP-R0`, `RP-R1a` |
| Usable layout/reactivity | Single segmented `VStack` does not implement the approved desktop shell and can appear inert. | `RP-R0`, `RP-R1b` |
| CSV selection/import | Picker is unreachable before workspace creation; importer requires literal `title` and `company` headers. | `RP-R1a`, `RP-R3` |
| Opportunity fields | Compensation, location, responses, and application/status dates are absent. | `RP-R2` |
| CSV mapping/update | No mapping or field-selected update-existing decision. | `RP-R3` |
| Reconciliation | Manual evidence log only; no direct check, outcome taxonomy, retry, or closure confirmation. | `RP-R4`, `RP-R5` |
| AI ledger | Static copy, not a searchable empty local ledger. | `RP-R8` |
| ADR-001 lifecycle | No portable recovery key/archive, encrypted-default export, expiry, or purge. | `RP-R7a`, `RP-R7b` |
| Document references | Metadata/hash only; no durable open/relink behavior. | `RP-R6` |
| Settings | Does not expose actual lifecycle/recovery/export state. | `RP-R9` |

## Controlled queue

| ID | Scope | Dependencies | State | Required evidence | Gate decision |
| --- | --- | --- | --- | --- | --- |
| `RP-R0` | Evidence-only baseline in a dedicated disposable test workspace/app-data location: first launch, default-page workspace access, pre-workspace CSV availability/explanation, page-state refresh, and mockup divergence. No behavior changes or modification of the user’s workspace/Keychain data. | None | **Accepted** | Redacted reproduction notes/screenshots, exact state transitions, build/OS/window details, and committed evidence path. | Amended boundary accepted. The evidence establishes the first-run/default-page, pre-workspace CSV guidance, page-refresh, and shell defects. Runtime create → CSV-preview/refresh is owned by `RP-R1a`. |
| `RP-R1a` | Typed workspace gate: visible create/open/recover/retry states for database artifacts × no key, primary only, pending only, and both keys. Ambiguous combinations are recovery-required: no overwrite, promotion, ignored key, or automatic key deletion. A non-secret durable creation journal records staging/pending-written/database-promoted/primary-promoted/cleanup-pending phases. Creation never deletes a committed database on an open error. | `RP-R0` | **Accepted** | State/failure tests, a macOS build, an isolated temporary-app smoke, and direct user observation of create workspace → native CSV dialog → fixture preview. The smoke record is manual UI evidence, not an automation claim. | All independent roles approved. The residual native-dialog observation risk is explicitly manual/user-observed. Release `RP-R1b` only. |
| `RP-R1b` | Reactive `NavigationSplitView` shell aligned with approved mockup structure and usable in a small window. | `RP-R1a` | **Accepted** | Debug build, focused navigation tests, isolated sandbox smoke, direct user 900×640 smoke, and all required independent approvals are recorded. | Delivery accepted R1b. Release `RP-R2` only. |
| `RP-R2` | Migration plus editable compensation, location, response state/history, and application/status dates. | `RP-R1b` | **Accepted** | Existing-workspace migration and create/edit/relaunch activity evidence, plus the corrective clock/date, real-v15-fixture, atomic-rollback, and deterministic-history evidence. | Corrective pass accepted at `c205e76` after independent review and a passed product-owner isolated smoke. Release `RP-R3` only. |
| `RP-R3` | Core CSV workflow: map → validate → row decision → atomic import report; field-selected update-existing with no silent overwrite. | `RP-R2` | **Accepted** | Standard-header, nonstandard-header, invalid-row, duplicate, reimport, prior-report rollback, and final product-owner workflow verification. | Accepted after the product owner passed the end-to-end workflow. R4 is next up for its required plan/privacy gate; no successor implementation is released. |
| `RP-R3a` | Resumable in-progress batch and bounded Undo Import. | `RP-R3` | Deferred by product owner | Separate recovery/history design and evidence. | Explicitly deferred to keep R3 focused; not released. |
| `RP-R4` | Reconciliation contract and local workflow states only: safe URL validation, classifications, evidence/error, confidence, retry de-duplication, closure confirmation; no request yet. | `RP-R3` | **Accepted** | Focused migration/task-isolation/startup verification, independent Architect/QA/Code Review approval, and product-owner hands-on verification. | Accepted; no network capability was released. R5 is Next up for its own plan and privacy/network gate. |
| `RP-R5` | User-initiated public-URL check: direct GET only, bounded/no-auth/no-script request, offline/manual-review handling, retry task, no auto-close. | `RP-R4` | **Accepted** | Focused correction verification, independent Code Review/QA/Architect approvals, and product-owner hands-on verification. | Accepted after the corrected implementation proved peer-bound, bounded, no-redirect public URL checking with manual closure only. The later product-owner UX-R1 → UX-R2 → R6 sequence now governs successor release. |
| `UX-R1` | Shell and opportunity navigation: native icon/compact sidebar emblem, first-run onboarding, Home default with Needs Attention as its first section, Pipeline-owned add/import entry points, consistent Rekon tokens, responsive empty states, scrollable Pipeline → dedicated opportunity overview, Activity & history and Reconcile posting sub-screens, and a compact overview document area. | `RP-R5` | **In progress — Task 2 released** | Task 2's synthetic-only immutable verifier and signed Keychain-transfer proof may proceed. Task 3 live handoff requires a fresh user-facing approval and separate Architect, Security/Privacy, TPM, QA, Code Review, and Delivery gates. | No user workspace, external-folder selection, production Keychain item, live handoff, UX-R2, or R6 is released. |
| `UX-R2` | Pipeline-owned core workflow forms: Add Opportunity layout/validation/structured action details and creation-date default; contact validation/employer association/expandable text; and staged CSV mapping/review/completion redesign. | `UX-R1` | Backlog | Focused workflow/form verification and product-owner hands-on review. | Product-owner approved; release only after UX-R1 acceptance. |
| `RP-R6` | Security-scoped document bookmark, open/verify/relink, hash revalidation, and relink-required after portable restore. No copy/edit/parse. | `UX-R2` | Backlog | PDF/DOCX attach, relaunch/open, moved-file relink, permission failure smoke. | Deferred until UX-R2 creates the approved compact document area. |
| `RP-R7a` | Recovery-key enrollment/verification, authenticated portable archive/export default, manifest, and restore-as-new-workspace. | `RP-R6` | Backlog | Recovery-key, portable restore, encrypted/default-export evidence. | Requires Architect + Security/Privacy approval before release. |
| `RP-R7b` | 30-day expiry display, deleted-data disclosure, and verified retained-backup purge/rebuild. | `RP-R7a` | Backlog | Expiry and purge success/failure evidence. | Architect + Security/Privacy approval required. |
| `RP-R8` | Empty read-only local AI ledger with time, feature, opportunity, route, model, completion, and cost filters. No AI/network/metrics execution. | `RP-R6` | Backlog | Every filter works at zero entries; no entry/network is produced. | Release only in serial order after its predecessor gate is accepted. |
| `RP-R9` | Settings exposes real recovery, expiry, deletion, export, document-reference, and ledger state; no fake integration controls. | `RP-R6`, `RP-R7b`, `RP-R8` | Backlog | Settings state matches stored state across relaunch. | Pending dependencies. |
| `RP-R10` | Clean-state, hands-on acceptance of all remediation tasks and candidate-package status reconciliation. | `RP-R1a`–`RP-R9`, `UX-R1`, `UX-R2` | Backlog | Full user workflow evidence and independent milestone reviews. | Pending every preceding task. |

### UX-R1 external-workspace bookmark Task 1 review and release

| Role | Decision | Evidence / required correction |
| --- | --- | --- |
| Product owner | **Approved ADR-003** | Select the existing folder once and retain least-privilege read/write security-scoped access. No copy, move, reset, or deletion. |
| Planning | **Approved Task 1** | The bookmark/recovery slice is dependency-safe and does not release Keychain work, UX-R2, or R6. |
| Architect / Security | **Approved Task 1** | Temporary direct `workspace.sqlite` validation precedes atomic bookmark replacement; invalid/cancelled selection retains the prior bookmark and remains recovery-only; lease ownership is explicit. |
| QA / Security | **Approved Task 1** | Wrong/empty/stale/cancelled selection and every lease-close path have focused acceptance evidence. Signed Debug entitlement evidence must show sandbox plus user-selected read/write only. |
| TPM / Delivery | **Accepted — Task 1 completed sub-slice** | Commits `f1b0c58` and `45583f7` satisfy ADR-003's user-selected read/write folder bookmark and recovery-only boundary. Focused `xcodebuild test` passed; signed Debug entitlement inspection verified App Sandbox with user-selected read/write access only. `UX-R1` remains **In progress**. Task 2's true read-only verifier and signed synthetic Keychain-transfer proof, and Task 3's live handoff, remain unreleased and separately gated. |

### UX-R1 Task 2 synthetic preflight review and release

| Role | Decision | Evidence / boundary |
| --- | --- | --- |
| Planning | **Approved** | The synthetic preflight is dependency-safe and its exit explicitly releases no live handoff work. |
| Architect / Security | **Approved** | Three distinct signed artifacts, immutable/no-follow verification, a shared nonce-bound synthetic fixture, narrow add-only Keychain interfaces, and a source-excluded helper boundary resolve the storage and transfer risks. |
| QA | **Approved** | Runtime configuration rejection, manifest continuity, exact SQLite-call capture, URI/no-follow negatives, terminal-failure preservation, and signature/entitlement evidence are focused and sufficient. |
| TPM | **Approved — release-safe** | Task 2 alone may proceed. UX-R1 remains In progress; Task 3, UX-R2, and RP-R6 remain unreleased. |
| Delivery Manager | **Released — Task 2 synthetic preflight only** | Run only the disposable read-only SQLCipher and signed Keychain-transfer proof in its canonical app-container synthetic root. A failure stops work; success does not authorize live migration, user-folder selection, or production Keychain access. |

### UX-R1 Task 2a core safety-boundary acceptance

| Role | Decision | Evidence / boundary |
| --- | --- | --- |
| Implementer | **Completed** | Commits `5781f1a` and `eaee28d` provide immutable/no-follow SQLCipher verification, trusted synthetic-root validation, mandatory fixture capability before any Keychain read, and add-only Data-Protection migration behavior. |
| Code Review | **Approved** | The scoped corrective review found no P0/P1 after the trusted-root, sentinel, duplicate-conflict, failure-manifest, and partial-handle fixes. |
| QA | **Approved** | Focused migration/verifier tests passed; rejected roots do not resolve or access adapters, Keychain reads require a validated fixture, and failure paths compare artifacts. |
| Delivery Manager | **Accepted — Task 2a core only** | The signed three-artifact harness is explicitly deferred as Task 2b. It is not a live-handoff authorization and cannot block the remaining UX-R1 work. |

### UX-R1-W1 separate local workspace review and release

| Role | Decision | Evidence / boundary |
| --- | --- | --- |
| Product owner | **Approved** | Offer a clearly labeled separate local workspace so app use can continue while the preserved workspace remains untouched. |
| Architect / Security | **Approved with isolation conditions** | Use a persisted UUID selector, compiled local-root derivation, and a distinct local Keychain service/accounts. Preserve the recovery bookmark and forbid legacy/production Keychain access. |
| QA | **Approved** | Focused proof covers isolated create, relaunch, preserved-material no-call/no-change, failure retention, and return-to-recovery. |
| TPM / Delivery | **Released — UX-R1-W1 only** | This is a recovery-onboarding usability bridge, not Task 3. UX-R1 stays In progress; Task 2b/Task 3, UX-R2, and R6 remain unreleased. |
| Code Review / QA | **Implementation approved** | Commits `a9d827d` and `9ed80e7` isolate the UUID-derived local workspace from recovery data, prevent test access to live storage, and preserve recovery-only actions after failure. Focused lifecycle tests passed. |
| Product owner | **Hands-on verification requested** | A fresh signed Debug build is open. Verify: recovery onboarding → Create separate local workspace → create one opportunity → quit/relaunch → opportunity remains; then Settings → Return to preserved workspace recovery leaves the original recovery state intact. |
| Code Review / QA | **Correction approved** | The failed first-run path was traced to a missing signed Keychain access group. The corrected build carries `2UA854NLX4.com.rekonlabs.RekonPursuit`; retry removes only an otherwise empty `.staging` journal, while every database/key-bearing or later-phase state remains recovery-only. Focused regression test and full local test run passed. |
| Product owner | **Accepted** | The corrected separate local workspace creation flow worked in the fresh app. |

## Review record

| Role | Decision | Findings that changed the plan |
| --- | --- | --- |
| Planning | Approved `RP-R0` brief | Established `RP-R0` through `RP-R10`; lifecycle was later split. |
| Architect | Approved `RP-R0` release | Required isolated baseline evidence; accepted the `R1a`/`R1b`, `R4`/`R5`, and `R7a`/`R7b` boundaries. |
| QA | Approved `RP-R0` release | Confirmed reproducible first-run/CSV/reactivity/layout evidence requirements without a coverage or CI expansion. |
| TPM | Approved `RP-R0` release | Confirmed no Phase 2 scope and no remaining product decision. |
| Delivery Manager | Approved `RP-R0` release | Confirmed this ledger/brief are canonical and only `RP-R0` may proceed. |

### RP-R1a amended-brief review record

| Role | Decision | Evidence |
| --- | --- | --- |
| Planning | Approved | The non-destructive workspace-state and phase boundaries are dependency-safe; recovery copy must not promise recovery without a database. |
| Architect | Approved | The complete database/key matrix, durable non-secret journal, recovery-required handling, and injected-failure boundaries resolve the interrupted-creation ambiguity. |
| QA | Approved | Focused local state fixtures and one isolated runtime smoke cover preservation without a coverage/CI expansion. |
| Security/Privacy | Approved | The compiled immutable Keychain namespace, non-destructive key handling, and redacted evidence rules prohibit paths, Keychain metadata, keys, and fixture content. |
| TPM | Approved | The amended R1a scope is dependency-safe and remains limited to the non-destructive workspace gate and post-create CSV reachability. |
| Delivery Manager | Approved — released for implementation | R1a is the only active task; visual-shell alignment and every successor remain out of scope. |

### RP-R1a implementation verification record

| Role | Decision | Evidence |
| --- | --- | --- |
| Code Reviewer | Approved | Native single-file `NSOpenPanel`, read-only entitlement binding, one CSV security-scope owner, and manual-vs-automated smoke wording were reviewed at current implementation head. |
| QA | Approved | Focused workspace/view-model tests passed (22 tests, 0 failures); Debug macOS build and isolated smoke passed. The product owner directly confirmed the current temporary app’s workspace-create → Import CSV → Choose CSV file → synthetic-fixture preview sequence. |
| Architect | Approved | Workspace recovery and mutation boundaries remain non-destructive; the CSV picker is UI-only, sandbox-appropriate, and nonpersistent. No ADR deviation is required. |
| Security/Privacy | Approved after remediation | CSV access is single-file/read-only with balanced scoped-resource cleanup and no upload/bookmark. The temporary smoke is isolated from production data. A real local path was redacted from the handoff and reachable history; the rewritten history and current tree were rechecked. |
| TPM | Approved for final gate | R1a stayed within workspace initialization/recovery and CSV-picker reachability. R1b+ scope did not enter the slice; the native dialog check remains documented as direct manual evidence. |
| Delivery Manager | Approved — R1a accepted | Rechecked the final ledger, clean worktree, scoped implementation, isolated smoke, and user-observed native dialog. Released `RP-R1b` only. |

### RP-R1b plan approval record

| Role | Decision | Evidence |
| --- | --- | --- |
| Planning | Approved | [R1b shell brief](task-briefs/RP-R1b-reactive-application-shell.md) at `d9190a0`: reactive desktop shell only; existing isolated harness owns mutable smoke; R1a recovery tests remain authoritative. |
| Architect | Approved | Parent-owned file/modal intents, unchanged native CSV and workspace boundaries, no test-injection seam, and an enforceable compact-window limit. No ADR change required. |
| QA | Approved | Non-mutating UI checks plus the existing isolated temporary-app manual smoke cover 900×640 navigation/reactivity and the actual CSV preview without coverage or hosted-CI expansion. |
| TPM | Approved | R1b is the sole dependency-safe successor; no R2+ scope or successor release is implied. |
| Delivery Manager | Approved — released for implementation | Durable record rechecked; R1b was released as the sole successor. |

### RP-R1b implementation verification record

| Role | Decision | Evidence |
| --- | --- | --- |
| Code Reviewer | Approved | Navigation and workspace-gate tests assert real stable accessibility elements; focused UI suite passed. No persistence, file-access, or R2+ scope change was found. |
| QA | Approved | Focused UI/model checks, Debug build, and isolated harness passed. The 900×640 temporary-app sequence is recorded as direct user evidence, not automation. |
| Architect | Approved | The new shell preserves R1a workspace/recovery, native CSV ownership, local-only boundaries, and existing persistence; no ADR change is required. |
| TPM | Approved for acceptance | R1b stayed shell-only. Release exactly `RP-R2` next; later direct successors remain blocked to avoid shared persistence/UI work. |
| Product owner | Completed manual smoke | At 900×640 in the isolated temporary app: workspace create; synthetic record create/edit; Pipeline and Activity & AI navigation; native CSV chooser and fixture preview all passed. |
| Delivery Manager | Approved — R1b accepted | Final independent gate complete. Released `RP-R2` only; `RP-R3`–`RP-R10` remain blocked to avoid overlapping persistence/UI work. |

### RP-R2 plan approval record

| Role | Decision | Evidence |
| --- | --- | --- |
| Planning | Approved | [R2 opportunity-fields brief](task-briefs/RP-R2-opportunity-fields-and-migration.md) at `9502268`: migration, core fields, explicit response/stage-date semantics, and R3 mapping exclusion. |
| Architect | Approved | Coherent schema/default/migration contract; fixed work-arrangement values; stage and response audit semantics; existing CSV safe defaults without mapping scope. No ADR change required. |
| QA | Approved | Deterministic focused migration/create/edit/relaunch/history checks include history ordering and optional-date clearing; no coverage/CI expansion. |
| TPM | Approved | R2 is the sole released scope; all successors remain blocked. |
| Delivery Manager | Approved — released for implementation | Plan record is dependency-safe. R2 is the only implementation task; `RP-R3`–`RP-R10` remain blocked. |

### RP-R2 corrective-pass decision record

| Role | Decision | Evidence / boundary |
| --- | --- | --- |
| Planning | Correction brief issued | Independent Architect and QA review of `2851b84` found stale initialization-time audit timestamps, new-form date carryover, an invalid version-16 failure setup, and missing R2 edge-case coverage. The R2 brief now requires one injectable clock sampled per mutation and per Needs Attention read, with stepwise quick-stage, task-action, multi-row existing-CSV, and read-time regressions; atomic create rejection of a non-default response without a date; explicit date validation; fresh new-form defaults; a real v15 fixture; atomic update rollback; and deterministic history ordering. |
| QA failure classification | Stage-history ordering: R2-caused; import-report equality: not R2-caused | A selected effective stage date makes `ORDER BY occurred_at, rowid` nondeterministic/semantically wrong for R2; the correction fixes it with `occurred_at ASC, id ASC` and tie tests. The import-report equality precision failure predates R2’s report contract and is explicitly deferred without an R2 code change. |
| Architect | Approved | Explicit-date rejection, one injected clock per mutation/time-dependent read, real v15 fixture, and deterministic ordering preserve the R2 contract. |
| QA | Approved | Stepwise clock checks cover quick stage, task, existing multi-row CSV, and Needs Attention without opening R3 mapping scope. |
| TPM | Approved | Corrective work remains R2-only; import-report precision remains deferred test hygiene. |
| Delivery Manager | Approved — corrective implementation released | R2-only clock/date, migration-fixture, form-lifecycle, and ordering correction is released. `RP-R3`–`RP-R10` remain blocked. |

### RP-R2 corrective implementation verification record

| Role | Decision | Evidence |
| --- | --- | --- |
| Code Reviewer | Approved | Final review at `c205e76` found the production dynamic-clock wiring, explicit date validation, atomic rollback, real v15 fixture, fresh form defaults, and deterministic histories correct and within R2 scope. |
| QA | Approved for manual smoke | Debug build and focused correction checks passed; the required isolated manual smoke remained the final direct-product check. |
| Architect | Approved | The dynamic-clock and migration/data contracts remain coherent; no ADR deviation is required. |
| TPM | Approved for acceptance | Corrective scope stayed inside R2; release `RP-R3` only. |
| Product owner | Passed isolated smoke | In the generated sandboxed app, the required synthetic create/edit/reset/clear/relaunch flow passed and Pipeline/Needs Attention refreshed normally. |
| Delivery Manager | Accepted — R2 accepted | The corrective evidence, independent approvals, and product-owner smoke are complete. Release `RP-R3` only; keep `RP-R4`–`RP-R10` blocked. |

### RP-R3 amended-plan approval record

| Role | Decision | Evidence |
| --- | --- | --- |
| Architect | Approved | The core local mapping/validation/explicit-decision/atomic-report contract preserves selected-field and task/due-date integrity; no ADR is required. |
| QA | Approved | Focused evidence covers standard/nonstandard headers, invalid rows, explicit selected-field updates, duplicate/reimport behavior, atomic rollback preserving prior report/data, and report reopen; no CI or coverage expansion. |
| TPM | Approved | `RP-R3` is the sole dependency-safe successor. `RP-R3a` is explicitly deferred; all other tasks remain blocked. |
| Delivery Manager | Approved — released for implementation | Product-owner scope decision and all amended plan approvals are recorded. Release `RP-R3` only. |

### RP-R3 final acceptance record

| Role | Decision | Evidence / boundary |
| --- | --- | --- |
| Product owner | **Accepted** | The fresh isolated R3 app completed the end-to-end CSV workflow: map, validate, decide, import, open the resulting opportunity, and retain the completed local report after reopening. |
| Delivery Manager | **Accepted — R3 complete** | Targeted corrective verification, the focused durable-report reload check, and the product-owner acceptance are recorded. R4 is Next up for planning and privacy/network approval only; no R4 implementation is released. |

### RP-R4 plan and release record

| Role | Decision | Evidence / boundary |
| --- | --- | --- |
| Planning | Approved | The R4 brief is bounded to durable local review state, task linkage, explicit closure confirmation, migration provenance, and focused verification. |
| Architect | Approved after P1 remediation | The v19 contract uses a dedicated reconciliation review/task link, preserves legacy IDs/status, makes closure explicit, and keeps the system-browser link outside app transport. |
| Security/Privacy | Approved after P1 remediation | No app transport is added; unsafe URL schemes, credentials, localhost, and literal loopback/link-local/private IP hosts are rejected. R5 owns DNS/redirect validation. |
| QA | Approved after P1 remediation | The brief covers v18→v19 provenance/rollback, invalid and injected-failure atomicity, task dedupe, cancel/confirm closure, and explicit no-network source/entitlement evidence. |
| TPM | Approved | The controlling sequence is `R3 → R4 → R5`; R4 is local-only and R5 remains unreleased. |
| Delivery Manager | **Approved — R4 released** | All plan P1s are resolved and recorded. Move only R4 from Next up to In progress; do not release R5 or any network capability. |

### RP-R4 in-progress corrective evidence

Startup verification exposed a deterministic local-store deadlock when the
selected opportunity had reconciliation history: `reconciliationReviewTask`
held the store's non-recursive lock and re-entered it through `taskReminder`.
The correction performs the reminder read inside the existing lock; it does
not change the locking model or add a concurrency refactor. Focused store,
migration, and view-model startup checks pass, including a seeded local review
task at startup. R4 remains **In progress**; this is evidence only and does
not release R5.

### RP-R4 acceptance record

| Role | Decision | Evidence / boundary |
| --- | --- | --- |
| Architect | **Approved** | Final R4 review found the local task/migration invariants intact and no network API or network-client entitlement. |
| QA | **Approved** | Focused startup, import/task-isolation, deletion lifecycle, and v18→v19 migration checks passed. |
| Code Review | **Approved** | The closure, legacy-write removal, URL-validation, and task-isolation fixes are present; no material regression found. |
| Product owner | **Accepted** | Hands-on verification completed the valid-URL, local `Closed suggested` review, and explicit closure flow. |
| Delivery Manager | **Accepted — R4 complete** | Move R4 to Accepted and R5 to Next up only. R5 requires its own planning and privacy/network gate; no R5 implementation is released. |

### RP-R5 plan and release record

| Role | Decision | Evidence / boundary |
| --- | --- | --- |
| Product owner | **Approved** | Redirects are never followed automatically; their target is evidence/manual review only. |
| Planning | **Approved** | The brief defines one explicit HTTPS check, deterministic classifier, exact v20 provenance, manual-review fallback, and no successor release. |
| Architect + Security/Privacy | **Approved** | The brief requires peer-bound `NWConnection` transport, HTTPS-only/default trust, no URLSession fallback, no credentials/cookies/redirects, strict public-address proof, and redacted persistence. |
| TPM + QA + Delivery | **Approved** | Scope is dependency-safe, fixture-only verification is proportionate, and dashboard semantics reserve In progress for released implementation. |
| Delivery Manager | **Released — R5 implementation** | Move only R5 from Next up to In progress. Implement the brief; do not release R6 or any unrelated network capability. |

### RP-R3 corrective verification record

| Role | Decision | Evidence / boundary |
| --- | --- | --- |
| Product owner | Passed targeted corrective verification | The user verified the fresh isolated app after the two reported defects were corrected: CRLF CSV files now present only their header row in mapping menus, and **Open resulting opportunity** now navigates to the imported record in Pipeline. This accepts those corrections only; the broader R3 map → validate → decide → import → reopen-report workflow remains in progress. |
| Code Reviewer | Approved | `8467af7` keeps the report-row selection behavior and adds the missing Pipeline destination change; no import or persistence behavior changed. |
| QA | Approved | Focused Debug build passed for the open-result correction. |
| Architect | Approved | The CRLF parser correction (`0ef9f90`) and report-navigation correction (`8467af7`) preserve the local-only import and opportunity-record boundaries. |

## Release log

| Date | Task | Delivery decision | Scope boundary |
| --- | --- | --- | --- |
| 2026-07-25 | `RP-R0` | **Approved — released** | It may create only redacted baseline evidence under `docs/delivery/evidence/remediation/RP-R0/` using a dedicated disposable test workspace and app-data location. It must not change production behavior, the user’s workspace, or Keychain data. `RP-R1a`–`RP-R10` remain blocked pending their stated dependencies and gates. |
| 2026-07-25 | `RP-R0` | **Accepted — amended gate** | Evidence boundary approved; runtime create/CSV-preview/refresh transferred to `RP-R1a`. |
| 2026-07-25 | `RP-R1a` | **Provisional release superseded** | The original release was withdrawn while the non-destructive workspace-state amendment was reviewed. The amended brief is ready for final TPM and Delivery release; no implementation began. |
| 2026-07-25 | `RP-R1a` | **Released for implementation** | Implement the approved non-destructive workspace-session gate and focused local verification in an isolated temporary namespace. Do not inspect, modify, delete, reset, or recover the user’s workspace or production Keychain material. `RP-R1b`–`RP-R10` remain blocked. |
| 2026-07-25 | `RP-R1a` | **Ready for final Delivery acceptance** | All independent implementation reviewers approve. The only remaining decision is Delivery Manager acceptance and, if accepted, release of `RP-R1b` only. |
| 2026-07-25 | `RP-R1a` | **Accepted — `RP-R1b` released** | Delivery Manager rechecked final evidence and approvals. The native picker’s dialog/preview remains direct user-observed evidence. `RP-R2`–`RP-R10` remain blocked. |
| 2026-07-25 | `RP-R1b` | **Accepted — `RP-R2` released** | Delivery Manager accepted the completed shell slice after independent Code Review, QA, Architect, TPM, and direct user 900×640 evidence. `RP-R3`–`RP-R10` remain blocked. |
| 2026-07-25 | `RP-R2` | **Released for implementation** | Delivery Manager approved the migration-and-core-fields brief. No successor is released; `RP-R3`–`RP-R10` remain blocked. |
| 2026-07-25 | `RP-R2` | **Implementation rejected — corrective pass planned** | Independent Architect and QA findings are reconciled in the R2 brief. This is not acceptance and does not release corrective code or any successor. |
| 2026-07-25 | `RP-R2` | **Corrective implementation released** | Delivery approved only the bounded R2 correction. R2 is not accepted; no successor is released. |
| 2026-07-25 | `RP-R2` | **Accepted — `RP-R3` eligible for amended plan gate** | Corrective evidence, independent Code Review/QA/Architect/TPM decisions, and product-owner isolated smoke are complete. `RP-R3` requires its own amended plan gate; `RP-R3a` and `RP-R4`–`RP-R10` remain blocked or deferred. |
| 2026-07-25 | `RP-R3` | **Scope decision — core flow first** | Product owner approved core mapping/validation/explicit decisions/selected-field update/report now. Resumable raw-file drafts and Undo Import are deferred to `RP-R3a`; no implementation begins until the amended R3 plan gate accepts. |
| 2026-07-25 | `RP-R3` | **Released for implementation** | Implement only map → validate → decide → atomic import → durable report. Do not retain raw CSV/resumable drafts; do not add Undo Import, contacts, reconciliation, lifecycle, or any successor. |
| 2026-07-25 | `RP-R3` | **Accepted — R4 Next up** | Product owner accepted the end-to-end isolated CSV workflow. Move R4 to Next up for its planning and privacy/network contract gate; do not start R4 implementation. |
| 2026-07-25 | `RP-R4` | **Released for implementation** | Implement only the approved local reconciliation contract and workflow states. No URL fetch, network entitlement, provider adapter, scheduled check, or R5 work is released. |
| 2026-07-26 | `RP-R4` | **Accepted — R5 Next up** | Product-owner hands-on closure verification and independent final approvals complete R4. R5 is eligible only for its planning/privacy-network gate; no R5 implementation is released. |
| 2026-07-26 | `RP-R5` | **Planning/privacy gate opened** | Product owner approved no automatic redirect following. Planning, architecture/security, TPM, QA, and delivery review are in progress. R5 remains Next up until Delivery releases implementation; no network implementation is released. |
| 2026-07-26 | `RP-R5` | **Released for implementation** | Independent plan/privacy gates approved the exact R5 brief. Implement only its explicit public URL check; R6 and all unrelated network capabilities remain unreleased. |
| 2026-07-26 | `RP-R5` | **Accepted — historical successor routing superseded** | Corrected implementation reviews and product-owner hands-on verification completed R5. The same-day UX sequence later superseded the interim R6-next routing; use the current controlled queue, not this historical record, for eligibility. |
| 2026-07-26 | `UX-R1` | **UX sequence approved — UX-R1 Next up** | Product owner approved UX-R1 → UX-R2 → R6. Move only UX-R1 to Next up; return R6 to Backlog and do not release any implementation. |
| 2026-07-26 | `UX-R1` | **Planning / Architect / QA / TPM approved** | The corrected brief resolves dashboard sequence semantics, stale UI-test wording, and route identity during reconciliation. |
| 2026-07-26 | `UX-R1` | **Released for implementation** | Delivery released UX-R1 only. Implement the committed brief; UX-R2 and R6 remain unreleased. |
| 2026-07-26 | `UX-R1` / `UX-R2` | **Home/Pipeline IA amendment approved** | Home is the default launch screen with Needs Attention first. Add Opportunity and Import CSV move from sidebar destinations into Pipeline actions. Rekon visual-token consistency and responsive empty states amend UX-R1; form, date-default, staged import, and Contacts improvements belong to UX-R2. URL detail extraction remains deferred. |
| 2026-07-26 | `UX-R1` | **Home/Pipeline amendment gate pending** | Original brief authority is limited to delivered work. The amendment brief controls the remaining Home/Pipeline scope and must clear Architect, TPM, QA, and Delivery before implementation or UX-R1 acceptance. |
| 2026-07-26 | `UX-R1` | **Home/Pipeline amendment — Architect approved** | No persistence, migration, network, or R5 route-safety conflict. The pure daily route seam preserves the existing guarded opportunity departure path. |
| 2026-07-26 | `UX-R1` | **Home/Pipeline amendment — TPM approved** | Amendment authority, active UX-R1 state, and UX-R2/R6 dependency boundaries are unambiguous. |
| 2026-07-26 | `UX-R1` | **Home/Pipeline amendment — QA approved** | The pure route-state seam and ready-state Home identifier provide focused evidence without UI-harness or coverage expansion. |
| 2026-07-26 | `UX-R1` | **Home/Pipeline amendment released** | Delivery released only the approved Home/Pipeline navigation, token-consistency, and responsive-empty-state amendment. UX-R2 and RP-R6 remain unreleased. |
| 2026-07-26 | `UX-R1` / Task 1 | **Released — external workspace bookmark only** | Implement only ADR-003's read/write folder bookmark and recovery chooser. No Keychain query/write/migration, database/WAL/SHM/journal mutation/copy/move/delete, or live user-workspace selection/verification is released. UX-R2 and RP-R6 remain Backlog. |
| 2026-07-26 | `UX-R1` / Task 1 | **Accepted — external-workspace bookmark sub-slice complete** | Commits `f1b0c58` and `45583f7` completed the ADR-003 bookmark/recovery slice with focused tests and signed Debug entitlement verification. This acceptance does not authorize Keychain query/write/migration, database/WAL/SHM/journal mutation, or any live user-workspace handoff. Keep `UX-R1` In progress; Task 2 and Task 3 remain unreleased. |
| 2026-07-26 | `UX-R1` / Task 2 | **Released — synthetic preflight only** | Implement the immutable read-only SQLCipher verifier and a three-artifact disposable legacy-to-DP Keychain proof in one nonce-bound canonical app-container fixture. Do not select or access a user workspace, external folder, production Keychain item, or live handoff. On any failure, stop. Task 3, UX-R2, and RP-R6 remain unreleased. |

## Risks and decisions

| ID | Decision / risk | Owner | State |
| --- | --- | --- | --- |
| `RP-D1` | Reconciliation may perform a user-initiated direct public-URL request. It never auto-closes an opportunity. | Product owner | Accepted 2026-07-25 |
| `UX-D1` | Complete the Rekon Pursuit brand pass: a native macOS app icon derived from the target/arrow emblem and a compact emblem in the sidebar header. Keep the toolbar functional; do not center a full horizontal wordmark on every screen. The placeholder icon and plain title pill are not acceptable. | Product owner | Accepted 2026-07-26; queued for the UX remediation pass before R6 implementation. |
| `UX-D2` | Workspace creation belongs to dedicated first-run onboarding, not Settings. Once a workspace exists, daily views must not repeat a workspace card; workspace health, backup/recovery, and privacy details belong in Settings. | Product owner | Accepted 2026-07-26; queued for the UX remediation pass before R6 implementation. |
| `UX-D3` | Pipeline is a scrollable list/board. Selecting an opportunity opens a dedicated overview screen that preserves the prior list filter and scroll state on Back. Do not use a permanent below-list editor or floating pop-up card. | Product owner | Accepted 2026-07-26; queued for the UX remediation pass before R6 implementation. |
| `UX-D4` | Opportunity activity, stage/response history, contacts, and relationship history are a dedicated **Activity & history** opportunity sub-screen, not permanent inline content or a detached global history page. | Product owner | Accepted 2026-07-26; queued for the UX remediation pass before R6 implementation. |
| `UX-D5` | Reconciliation is a dedicated **Reconcile posting** opportunity sub-screen. Document references remain a compact overview section with on-demand management; do not add a full documents screen for the MVP. | Product owner | Accepted 2026-07-26; queued for the UX remediation pass before R6 implementation. |
| `UX-D6` | The Add Opportunity/overview form uses a multi-line job-description field; URL shape validation with non-HTTPS warning but preservation of imported historical URLs; structured compensation (USD default, min/max, pay period); free-text location paired with work arrangement; and a next-action type picker with optional custom text for Other. Remove global workspace, count, activity, and status-footer clutter from focused form/detail screens. | Product owner | Accepted 2026-07-26; queued for the UX remediation pass before R6 implementation. |
| `UX-D7` | CSV import is a dedicated choose → map → review/decide → completion flow. Completion summarizes totals and offers **View imported opportunities** in Pipeline. It surfaces only invalid, duplicate, skipped, updated, or failed exceptions; a secondary full report identifies opportunities by title/company, not routine “Row N: created” output or one open button per successful row. | Product owner | Accepted 2026-07-26; queued for the UX remediation pass before R6 implementation. |
| `UX-D8` | Contacts validate email syntax only and validate a well-formed profile URL with a non-HTTPS warning; they do not claim deliverability or restrict profile providers. Employer is a searchable picker of canonical employers inferred from tracked opportunity companies, with **Add new employer** when unmatched. Employer association exposes that employer’s tracked opportunities; direct contact-to-opportunity links remain an explicit user choice. Relationship context and notes are separate compact multi-line fields with user-triggered expansion. | Product owner | Accepted 2026-07-26; queued for the UX remediation pass before R6 implementation. |
| `UX-D9` | UX-R1 introduces a restrained Rekon visual token layer: deep navy/near-black surfaces, blue-to-violet accents for primary actions and active selection, fine navy borders, bright primary text, and blue-gray secondary text. Keep the productivity UI calm and readable; do not reproduce marketing-page glow, decorative charts, or pervasive gradients. | Product owner | Accepted 2026-07-26; part of UX-R1. |
| `UX-RISK-1` | Stable Personal-Team signing is configured and verified, but the sandboxed app cannot access the legacy key or write to the preserved external workspace. The recovery screen is safe but cannot resolve either boundary. Do not delete, recreate, overwrite, extract, or log the database/Keychain material. | Product owner + Architect + Security/Privacy | **Mitigating — Task 1 released** — implement persistent user-selected read/write folder access with no copy; risk remains open until isolated verification succeeds. |
| `UX-RISK-2` | The former Keychain-only handoff used a database API that opens read/write and enables WAL, so it would violate read-only verification. It also relied on entitlement comparison rather than actual signed cross-build Keychain behavior. | Architect + QA + Security/Privacy | **Open** — revised plan must add `SQLITE_OPEN_READONLY`, source/sidecar integrity checks, and a disposable signed cross-build synthetic transfer before a live workspace is touched. |
| `RP-RISK-1` | Direct URL requests can reach private/internal endpoints without explicit validation. `RP-R4` must reject non-http(s), credential-bearing, localhost, private, and link-local destinations. | Architect + Security/Privacy | Open |
| `RP-RISK-2` | Portable recovery/export/purge can cause data loss or false recovery claims. `RP-R7a/b` requires separate high-risk approval and restore-as-new-workspace. | Architect + Security/Privacy | Open |
| `RP-RISK-3` | The current candidate’s status claims obscured required work. This ledger is controlling until `RP-R10` is accepted. | Delivery Manager | Mitigated |
| `RP-RISK-4` | A store-wide initialization timestamp can make later audit events untruthful, while optional form dates can silently reuse a prior draft. | Architect + QA | Mitigated — RP-R2 corrective pass accepted |
| `RP-RISK-5` | The existing import-report equality test compares a precision-sensitive timestamp but is unrelated to R2’s report contract. | QA | Deferred — separate test-hygiene release required; no R2 scope expansion |
