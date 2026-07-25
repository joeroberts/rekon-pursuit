# Rekon Pursuit MVP remediation implementation plan

> **For agentic workers:** Follow the repository `AGENTS.md` roles and release one accepted task at a time. An implementer never reviews or verifies its own work.

**Goal:** Deliver the missing approved MVP behavior and make the actual app usable from a clean first launch.

**Architecture:** Correct the workspace state gate and root SwiftUI shell before adding record, import, reconciliation, lifecycle, document, ledger, and Settings behavior. Each task persists real local data and records the associated activity; connected reconciliation is the sole narrowly scoped public-web exception.

**Tech stack:** SwiftUI, Swift, SQLCipher-backed local store, App Sandbox, Keychain, security-scoped file access.

## Global constraints

- Local-first remains the default; no Gmail, Calendar, AI execution, research, document processing, interview, or offer work is included.
- Each task requires a persisted brief, a fresh implementer, a separate reviewer and QA verifier, Architect review, and Delivery release decision.
- No hosted test-suite or coverage gate is introduced; verification is focused local workflow evidence.
- The [remediation ledger](../../delivery/remediation-ledger.md) is the canonical task state.

## Task briefs

### RP-R0: Clean-state failure baseline

**Files:** Create `docs/delivery/evidence/remediation/RP-R0/RP-R0-baseline.md`; no production source changes.

**Scope:** Use only a dedicated disposable test workspace and test app-data location; never delete, reset, or modify the user’s actual workspace or Keychain data. Record app build/commit, macOS version, window size, initial database/key state, actions, observed result, and redacted screenshot paths under `docs/delivery/evidence/remediation/RP-R0/`. Capture: (1) whether Create Workspace is visible and actionable on first launch; (2) before creation, whether CSV import is visibly unavailable with an explanation; (3) whether the visible page change refreshes without relaunch; and (4) mockup-shell comparison screenshots. Runtime creation, post-create CSV preview, and post-create refresh belong to `RP-R1a`, which changes the workspace gate and CSV availability. No behavior change.

**Acceptance:** Evidence establishes whether default-page workspace access and pre-workspace CSV guidance are reachable, why they are not, and whether page state visibly updates; it does not claim a fix. `RP-R1a` owns the runtime create → CSV-preview verification.

### RP-R1a: Workspace session gate

**Files:** Modify `RekonPursuit/ContentView.swift`, `RekonPursuit/WorkspaceViewModel.swift`, `RekonPursuitCore/WorkspaceOpenState.swift`; add focused local tests beside existing workspace tests.

**Scope:** Replace hidden first-run creation with an explicit default-page workspace gate. Model missing workspace, database-present/key-missing, dangling-primary-Keychain-key/no-database, dangling-pending-Keychain-key/no-database, corrupt, locked, denied, unavailable, ready, retry, and recovery states. Open/retry never deletes a Keychain key. Create is unavailable while any database artifact or either Keychain key exists; recovery copy explains existing material is retained and offers no reset/replacement. Creation has explicit temporary, pre-commit, and committed phases: cleanup may remove only newly created pre-commit artifacts, and never deletes a committed database/key pair after a reopen error. Derive the Keychain service from immutable compiled bundle configuration, preserving `com.rekonlabs.RekonPursuit.workspace` for production; never route it through environment variables or user preferences. Enable CSV selection only after ready state and show why otherwise.

**Acceptance:** Focused fixtures for primary-key/no-database, pending-key/no-database, database/no-key, corrupt database, locked, and denied states preserve the original artifacts and block replacement as applicable. A fresh-launch smoke uses a distinct sandboxed temporary bundle, app-data container, and compiled Keychain service; entitlement inspection proves App Sandbox; production workspace and Keychain metadata remain unchanged. Create Workspace succeeds; pipeline and CSV entry point become reachable without relaunch; a synthetic fixture preview appears; failure/retry paths do not destroy existing data. Displayed diagnostics/activity contain no key material, sensitive filesystem paths, or fixture contents.

### RP-R1b: Reactive application shell

**Files:** Create focused shell/workspace SwiftUI views; modify `ContentView.swift`; add a small shared visual style component only if required.

**Scope:** Replace the segmented root with an observable `NavigationSplitView`, persistent branded sidebar, toolbar, scrollable detail workspaces, and explicit empty/loading/error states derived from the workspace gate. Match approved mockup hierarchy without changing feature scope.

**Acceptance:** Navigation, create/edit/import state changes visibly refresh immediately; all primary pages remain usable at a small desktop window; screenshots demonstrate the agreed shell structure.

### RP-R2: Opportunity record completeness

**Files:** Modify opportunity models, migrations, store commands, view model, record/pipeline UI, CSV/export projections, and focused local tests.

**Scope:** Add nullable/default-safe compensation (amount/currency/period), location/work arrangement, response state/history, application date, and status-change date. Persist every user change atomically with activity evidence.

**Acceptance:** Existing workspaces migrate; a user creates, edits, relaunches, and sees every new field without losing old records.

### RP-R3: Mapped CSV import and safe update-existing

**Files:** Modify import model/parser/store/view model/UI and local import fixtures.

**Scope:** Implement select → map columns → validate → duplicate rationale → Create / field-selected Update Existing / Keep Separate / Skip → durable report. Allowed import updates are title, company, URL, compensation, location, application date, and response/status dates; notes, description, next action, stage/closed state, contacts, document links, and history never change without a direct record edit. Resolve record-version conflicts by returning to review.

**Acceptance:** Nonliteral headers map successfully; invalid rows mutate nothing; each duplicate has a visible rationale; reimport creates no unintended duplicate or overwrite.

### RP-R4: Reconciliation contract

**Files:** Add reconciliation domain/service interfaces, local workflow UI, deterministic fixtures, and an ADR or specification amendment if Architect approves it.

**Scope:** Define URL validation, classifications (`still_open`, `possibly_closed`, `closed_suggested`, `ambiguous`, `failed`, `offline_unchecked`), safe evidence/error storage, confidence, retry de-duplication, manual-review task, and separate closure-confirmation command. Do not make any network request in this task.

**Acceptance:** Fixture-driven flows persist every outcome and never close an opportunity until an explicit confirmation command; Architect and Security/Privacy approve the request boundary before `RP-R5` opens.

### RP-R5: Direct public-URL reconciliation

**Files:** Add a bounded `URLSession` adapter, network entitlement, request disclosure, store commands, and focused fixtures/tests.

**Scope:** On explicit user action, issue one GET only for a saved public `http`/`https` URL. Reject credential-bearing URLs and validate the resolved destination before every request and redirect hop; reject loopback, private, link-local, and reserved addresses. Send no cookies/auth, execute no scripts, and use bounded redirects/body/timeout. Offline, blocked, changed, and failed outcomes create or reuse a manual-review/retry task. No result changes stage automatically.

**Acceptance:** Online, offline, changed, blocked, failed, and explicit-close flows meet the PRD and retain safe evidence locally.

### RP-R6: Document reference open and relink

**Files:** Modify document-reference model/migration/store/view model/UI and focused file-access tests.

**Scope:** Store an encrypted security-scoped bookmark with filename/hash; open/verify on user action; show available, moved, missing, and permission-denied states; relink only through user selection and hash revalidation. Portable restore marks references relink-required.

**Acceptance:** PDF/DOCX reference survives relaunch and opens; a moved file requests relink and never falsely claims availability.

### RP-R7a: Portable recovery and encrypted-default export

**Files:** Add versioned encrypted archive/recovery-key services, manifest/catalog storage, restore-as-new-workspace UI, and focused recovery tests.

**Scope:** Enroll and verify a user-held, non-resettable, non-escrowed recovery key; bind it to authenticated archive metadata; generate authenticated encrypted archives with manifest verification; default export to encrypted; require warning and final destination/filename review for unencrypted export; restore verifies then creates a new workspace rather than replacing the active one.

**Acceptance:** A portable archive restores into a separate workspace using the recovery key; export choices and warnings are truthful; no secrets are exported.

### RP-R7b: Retention visibility and purge

**Files:** Modify backup catalogue, deletion views, purge service/UI, and focused lifecycle tests.

**Scope:** Show creation and 30-day expiry; disclose retained deleted data; purge app-managed retained backups by regenerate/verify/remove with truthful partial-failure state and dedicated confirmation.

**Acceptance:** Expiry and purge status survive relaunch; a failed purge is never reported as complete.

### RP-R8: Searchable empty AI ledger

**Files:** Add AI ledger schema/projection/filter UI and focused local tests.

**Scope:** Provide read-only filters for time, feature, opportunity, route, model, completion state, and cost range. It remains zero-entry, no-AI, no-network, and stores no prompt content.

**Acceptance:** Every filter is usable with zero entries, and the UI explicitly confirms no request has run.

### RP-R9: Lifecycle Settings

**Files:** Modify Settings views/view model and preference/storage projections.

**Scope:** Display actual workspace/recovery-key state, backups/expiry, deletion-retention disclosure, export controls, document-reference status, ledger entry point, and the closed-opportunity preference. Do not show AI or integration controls as active.

**Acceptance:** Settings reflects persisted state after relaunch and exposes only implemented capabilities.

### RP-R10: Integrated acceptance

**Files:** Create `docs/delivery/evidence/remediation/RP-R10-acceptance.md`; update roadmap/handoff/ledger only with verified results.

**Scope:** Hands-on clean-state verification of workspace setup, daily tracking, mapped import, reconciliation, lifecycle, references, empty ledger, Settings, and candidate package. Record remaining limitations plainly.

**Acceptance:** Architect, TPM, QA, Security/Privacy, and Delivery independently accept or reject evidence. Only then may the roadmap describe the MVP as complete.
