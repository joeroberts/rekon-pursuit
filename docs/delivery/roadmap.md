# Rekon Pursuit — Implementation Roadmap

## Purpose and delivery posture

Build a local-first, native-window Mac application that is useful without any account connection, preserves an auditable working record, and only performs connected or AI actions after an explicit user choice. This roadmap sequences a coherent first release (the PRD MVP) while establishing the shared architecture, data contracts, consent boundaries, and traceability required by later connected and AI-assisted capabilities.

The delivery principle is **vertical slices over isolated screens**: each slice must persist real data, expose recovery states, create the required activity evidence, and be acceptance-testable end to end. Mockups are interaction intent, not implementation scope; their safe-state behavior is binding where it reflects a PRD requirement.

## Current release status — source of truth

> **Superseded for MVP-completion reporting on 2026-07-25.** The unsigned candidate app exists, but independent remediation review found required MVP behavior missing and first-run use blocked. The controlling current record is the [MVP remediation ledger](remediation-ledger.md). The detailed workstreams and M0–M9 sequence below are historical planning context, not evidence that the MVP is complete.

| Release area | Current status |
| --- | --- |
| Remediation R1 | **Accepted historical evidence** — the remediation ledger records the accepted R1 sequence and evidence; it is not current implementation work. |
| Post-MVP refinement | **Active delivery queue** — VD2-01 is accepted. VD2-02 is next up under fresh independent gates; later children remain dependency-ordered Backlog. |
| Phase 2a — privacy and AI foundation | **Not started** — follows accepted Post-MVP refinement; local-model runtime, cloud routing/sanitization/consent, populated AI ledger, budgets, and costs remain Backlog. |
| Phase 2b — Gmail and Google Calendar | **Not started** — follows accepted Phase 2a. |
| Phase 2c — documents and research | **Not started** — follows accepted Phase 2b. |
| Phase 3 — interview and offer support | **Not started** — follows accepted Phase 2c. |

### Shipped MVP boundaries

- All MVP data remains local by default. The accepted R1 lifecycle work adds authenticated portable archive and restore-as-new-workspace recovery, encrypted-default logical export, automatic archive expiry, and verified-replacement retained-data purge; it does not add cloud storage.
- Reconciliation retains explicit user control: an accepted user-initiated, bounded public-URL check records the outcome and evidence, while a user still confirms any opportunity-stage closure. There is no automatic stage change.
- PDF/DOCX references support durable attach, open, verification, and moved-file relink while preserving the source file. The app does not copy, parse, edit, send, or upload files.
- AI execution, Gmail, Calendar, research, document generation/editing, interview tooling, and offer tooling are not part of this release.

## Architecture that spans every release

Implement these foundations before, or as part of, the first vertical slice; do not defer them in a way that creates a second architecture for later phases.

| Foundation | Required responsibility | First-release use | Later-release extension |
| --- | --- | --- | --- |
| Native shell and application services | Native Mac window, navigation, app lifecycle, error boundary, keyboard handling, offline state | Hosts tracker and local workflows | Hosts OAuth, AI, audio, export, and settings flows |
| Local data layer | Versioned local database, migrations, repository/service interfaces, attachments/document references, backup/export and deletion boundaries | Stores tracker, contacts, tasks, imports, checks, and logs | Stores integrations, document versions, interviews, offers, research, and AI ledger |
| Canonical domain model | Core records from the PRD plus stable IDs, timestamps, relationship links, status history, and source/provenance fields | Opportunity, Employer, Contact, Interaction, Task/Reminder, Import Batch, Job Posting Check, Activity Event | Document Version, Interview, Offer, Research Item, AI Usage Entry, connection metadata |
| Command and audit layer | All material user actions pass through commands that validate, persist, and append an activity event atomically | Creates/edits, stage changes, task actions, imports, duplicate choices, reconciliation decisions | Draft/send approvals, calendar confirmations, document revisions, AI executions, deletions |
| Work queue and derived-state service | Deterministic query rules for overdue, upcoming, manual-review, and deadline items; stable sort/tie-break behavior | Powers default Needs attention home | Incorporates interview prep, Gmail follow-ups, offer deadlines, and review tasks |
| Evidence and automation contract | An automation result includes input scope, result class, evidence/error, timestamp, confidence when applicable, and a next user-owned action | Posting reconciliation records and manual-review routing | Research, thread matching, transcript coaching, AI conclusions, calendar conflict checks |
| Privacy/permission boundary | Feature-scoped settings, encrypted-at-rest secrets/tokens, explicit execution modes, per-action disclosure/confirmation, retention and deletion policies | Local-only defaults, an empty/read-only searchable AI ledger, and future-safe settings/data boundaries | AI routing/ledger execution first, then Gmail, Calendar, and recording consent |
| Accessibility and state-system contract | Loading, empty, offline, permission-denied, failed, and success states; non-color status cues; visible focus; accessible labels; Escape cancellation | Required for all MVP flows | Reused by every connected and AI flow |

### Cross-cutting invariants

- The opportunity record is the canonical workspace: stage, next action, job source/description, notes/activity, contacts, document links, reconciliation evidence, and timeline remain navigable from one record.
- No import overwrites or merges a record without a row-level user decision. No reconciliation result changes a stage until a user explicitly confirms the closure.
- Every complete, snooze, reschedule, status action, import decision, check, and external execution creates a local activity event linked to its affected record(s).
- A failed, blocked, inaccessible, changed, or offline-unchecked job URL is a manual-review outcome, never closure evidence. When fully offline, reconciliation performs no check, preserves the last recorded result, displays `Offline — check not run`, and creates a retry/manual-review task without changing the opportunity.
- Future cloud AI cannot silently become the fallback for private content. Local, sanitized cloud, and full cloud are separate execution paths, and full cloud always requires its own per-action confirmation.
- Status is never color-only; time-sensitive surfaces show actual date/time and may add relative time.

## Ownership assumptions

| Role | Primary accountability |
| --- | --- |
| Product owner / PM | Resolves open product decisions, accepts scope gates, owns rollout and release acceptance. |
| Technical program manager | Maintains sequencing, dependency/risk log, milestone readiness, and cross-workstream acceptance evidence. |
| Tech lead / architect | Owns architecture decisions, local data/audit/permission contracts, migration strategy, and integration boundaries. |
| Mac application engineer(s) | Delivers shell, local domain workflows, accessible UI state handling, and integration surfaces. |
| Data/platform engineer (may be the tech lead) | Owns database migrations, repository contracts, attachment storage, export/deletion, and audit atomicity. |
| UX/product designer | Maintains interaction specifications from the reviewed mockups; validates safe confirmations, accessibility, and empty/error states. |
| QA / test owner | Defines fixture data, acceptance automation, migration/re-import regression coverage, and release evidence. |
| Security/privacy owner | Approves token protection, retention/deletion behavior, OAuth scopes, AI disclosure/sanitization, and permitted-source policy before those capabilities ship. |
| Integration/provider owner | Manages Gmail/Calendar OAuth configuration and permitted/licensed research providers when Phase 2 begins. |

For a small team, one person may hold multiple roles, but the accountability boundaries and approval gates still apply.

## Workstreams and vertical slices

### Workstream A — Product foundation and trust contracts

**Objective:** Establish the shell, local database, domain schema, audit command path, migrations, and interaction-state conventions that all features use.

**Vertical-slice exit:** A user can open the app, see an empty local workspace, create a minimal opportunity through the shared command layer, reopen the app, and see it persisted with a corresponding activity event. The UI demonstrates recoverable empty, validation-failure, and offline/local-only states.

**Dependencies:** Product decisions on supported macOS baseline, local encryption/backup/deletion posture including recovery-key behavior, and first-release attachment/document-link storage behavior. The local-data lifecycle gate must pass before M0/M1.

**Acceptance checkpoint:** Fresh install → create opportunity → quit/relaunch → open its activity timeline → verify stable record ID, timestamps, and event linkage. Force a validation error and confirm the user receives a specific correction path without losing entered data.

### Workstream B — Opportunity workspace, pipeline, and daily loop

**Objective:** Deliver the first useful daily workflow: add an opportunity → choose stage and next action → clear Needs attention.

**Scope:** Opportunity create/edit/search/filter; six fixed standard stages (custom stage administration deferred); board and table views; canonical opportunity record; task/reminder model; deterministic Needs attention queue; complete/snooze/reschedule/open actions; stage/status history; activity timeline. Manual-review work enters the queue only when its producing workflows ship in M5/M7.

**Vertical-slice exit:** A newly created opportunity with a linked next action appears in the default Needs attention home at the correct deterministic position; each queue action updates the task and activity log; the user can navigate from queue to the canonical record and back.

**Dependencies:** Workstream A; product-owner decision on initial stage set and deterministic urgency/order rules.

**Acceptance checkpoint:** Seed equal-priority overdue, due-today, upcoming, and no-due-date items. Verify documented ordering and a stable tie-breaker across relaunch. Complete, snooze, reschedule, and open each type; verify only the intended item changes and every action is logged.

### Workstream C — Contacts, interactions, and relationship links

**Objective:** Make relationship memory reusable independently of one opportunity.

**Scope:** Contact CRUD/search/filter; employer association; notes; interactions; last/next touch; many-to-many contact/opportunity links; explicit link/unlink; contact timeline; contextual contact discovery from an opportunity.

**Vertical-slice exit:** A user can create an unlinked contact, log an interaction, link that contact to multiple opportunities, and see the same relationship history from the contact and opportunity records.

**Dependencies:** Workstreams A and B; finalized relationship cardinality and delete/unlink semantics.

**Acceptance checkpoint:** Link one contact to two opportunities, unlink one, and verify the other remains intact. Log an interaction with an optional opportunity reference and verify it appears in the correct contact and opportunity timelines with no duplicate activity events.

### Workstream D — CSV import and duplicate-decision workflow

**Objective:** Support fast capture without record fragmentation or accidental overwrite.

**Scope:** File selection, column mapping, validation, local duplicate-candidate detection and rationale, row-by-row choice (keep separate/update existing/skip), import batch, import report, reversible-batch design, and activity traceability.

**Vertical-slice exit:** A mixed-validity CSV follows the reviewed flow exactly: map columns → validate rows → decide each duplicate → import eligible rows → review report. No external data is consulted.

**Dependencies:** Workstreams A and B; product-owner decision defining the initial duplicate-candidate signals and what an approved “update existing” may modify.

**Acceptance checkpoint:** Re-import the same fixture. Demonstrate that the second run produces visible duplicate candidates and cannot create an unintended duplicate or overwrite without an explicit choice. Inspect the import report and activity log for every row outcome, including invalid and skipped rows.

### Workstream E — Conservative posting reconciliation

**Objective:** Give users evidence-backed opening status review without unsafe automation.

**Scope:** Select active opportunities with URLs; execute checks only when online; retain URL, timestamp, outcome class, evidence/error, and confidence; display Still open/Possibly closed/Closed evidence; route ambiguous/failed/blocked/changed results to manual review; when offline, retain the prior result, display `Offline — check not run`, and create retry/manual-review work; confirm closure explicitly; record outcome and decision.

**Vertical-slice exit:** A user can inspect a batch with confirmed, ambiguous, and failed results, open the evidence, keep a role active, retry later, or explicitly confirm a well-supported closure.

**Dependencies:** Workstreams A and B; security/legal approval of implementation approach and source/request behavior; product-owner definition of evidence thresholds and supported outcome taxonomy.

**Acceptance checkpoint:** Use deterministic fixtures for: explicit “position filled,” changed page, access denied, transient failure, still-open posting, and offline. Confirm only explicit closure confirmation changes the stage. Verify every other fixture remains active/manual review and retains its evidence/error; the offline fixture makes no request, preserves the prior result, and creates a retry/manual-review task.

#### Planned extension — user-initiated job-detail extraction

**Status:** Future product capability; not part of the MVP remediation queue or automatic URL handling.

**Objective:** Let a user explicitly request an extraction preview from a public job URL for work arrangement, compensation, job description, and location.

**Scope and safety boundary:** Reuse the accepted public-URL request policy: one user-initiated bounded request, HTTPS/public-destination validation, no credentials/cookies/sign-in, no redirect following, and no background refresh. The app presents extracted values and confidence/provenance for review; it never silently overwrites user-entered fields. Ambiguous, inaccessible, unsupported, or incomplete pages remain manual entry. This capability does not use AI or cloud routing.

**Acceptance checkpoint:** Deterministic fixtures show an extractable posting, missing fields, contradictory values, a changed page, a blocked page, and a non-HTTPS historical URL. Confirm only explicit per-field or all-field user acceptance updates an opportunity and records activity evidence.

### Workstream F — MVP hardening, data lifecycle, and release readiness

**Objective:** Make the MVP reliable as a local daily tracker and ready to expand without reworking its trust model.

**Scope:** Searchability across tracker/contacts and activity events; an empty/read-only locally searchable AI-usage ledger; manually attached local DOCX/PDF reference links with source-file hashes and final-version-sent metadata; local backup/export and deletion behavior; migration/recovery checks; accessibility pass; performance and resilience checks; release notes/onboarding; telemetry only if locally privacy-reviewed and not required for core use. No document ingest, editing, transformation, versioning, or AI execution is in M5.

**Vertical-slice exit:** A user can complete the PRD MVP success workflow entirely offline after initial install, export their data, and understand the recovery path for unavailable inputs or a failed operation.

**Dependencies:** Workstreams B–E; resolved local retention/export/deletion policy.

**Acceptance checkpoint:** Run the full MVP acceptance suite on a clean workspace and a migrated fixture workspace. Verify export contains the expected local records and provenance while confidential data handling follows the approved policy. Validate keyboard-only use of queue, import, record, and confirmation surfaces. Search activity events by time, opportunity, event type, and completion state without displaying raw sensitive content. Search the empty/read-only AI ledger by its supported fields; verify its explicit empty state, that it creates no network activity or entries, and that DOCX/PDF attachments retain their hashes and metadata without processing.

### Post-remediation UX refinement queue

These are planned product refinements, not active remediation work. They must not
change release order until separately planned and released. They are visible as
Backlog under the Post-MVP refinement dashboard phase while this roadmap and the
remediation ledger retain sequencing and evidence authority.

| ID | Refinement | Intended outcome |
| --- | --- | --- |
| `UX-D11` | Split the existing **Activity & AI** destination into **Logs** and **AI ledger** tabs while retaining the same sidebar entry. | Each ledger has its own working area; neither search/filter surface is permanently stacked below the other. No AI execution, network capability, or new ledger data is introduced. |
| `UX-D12` | Refine local log search beyond token-only matching. | Preserve the current safe multi-word fallback, then add predictable phrase/ordered-term behavior and a clear way to target an exact event label or identifier so queries such as `CSV import row 2 created` do not also return rows 20, 21, and 22. Define ranking, matching, and empty-state behavior before implementation. |

### Visual Design v2 program

**Authoritative product-delivery record:** This section, together with
`docs/delivery/dashboard-status.json` and the local SDD progress ledger, is
the controlling delivery record for Visual Design v2. It is not remediation
work and its acceptance evidence must not be recorded in the remediation ledger.

**Design direction:** Recompose the native SwiftUI application around the
approved Rekon Pursuit visual language: deep layered navy surfaces, restrained
cyan/violet accents, an accessible left navigation rail, clear type hierarchy,
truthful cards, correct existing logo treatment, and native reduced-motion
behavior. Reference mockups are a design-system target, not fake data or a
pixel-copy mandate.

| ID | Child card | Dependency / current state |
| --- | --- | --- |
| `VD2-01` | Visual foundation and tokens | **Accepted.** The product owner accepted the corrected shared foundation after hands-on verification; fresh independent Architecture, Code Review, QA, and Security/Privacy gates remain recorded. |
| `VD2-02` | App shell and navigation | **Next up.** The sole dependency-safe successor; awaiting its fresh independent Planning, Architecture, TPM, QA, and Delivery Manager release gates. |
| `VD2-03` | Home redesign | Backlog — requires `VD2-02` accepted. |
| `VD2-04` | Pipeline table and inspector | Backlog — requires `VD2-02` accepted. |
| `VD2-05` | Pipeline board and persisted stage movement | Backlog — requires `VD2-04` accepted. |
| `VD2-06` | Contacts master/detail redesign | Backlog — requires `VD2-02` accepted. |
| `VD2-07` | Settings information architecture | Backlog — requires `VD2-02` accepted. |
| `VD2-08` | Visual QA and accessibility acceptance | Backlog — requires `VD2-03` through `VD2-07` accepted. |

Every child follows `Backlog → Next up → In progress → independent code
review / QA / security-privacy verification → product-owner hands-on
verification → Accepted`. The parent `DESIGN-V2` remains Backlog until all
eight children, including `VD2-08`, are accepted and the product owner accepts
the final visual and workflow verification. `needsUserAction` is true only for
an owner-smoke handoff, never for routine tests or documentation.

**Non-scope:** UX-D10, UX-D11, UX-D12, Phase 2a/2b/2c, Phase 3, AI execution,
Gmail, Calendar, research, document processing, connected services, browser
storage, plugins, cloud services, and web implementation remain unreleased.

### Workstream G — Privacy and AI foundation (Phase 2a)

**Objective:** Establish the privacy, routing, consent, and ledger contracts required before any AI feature or connected workflow.

**Slices (in dependency order):**

1. Model-route selection, local-runtime availability/failure states, sanitization configuration, full-cloud disclosure, and per-action consent/cancel paths.
2. Populated local AI ledger with redacted entries, local search, cost/pricing-version records, budgets/alerts, and no raw sensitive prompt content by default.
3. Fixture-backed consent, no-fallback, routing, ledger, and budget acceptance tests.

**Dependencies:** Accepted Post-MVP refinement; approved local-runtime policy, sanitization fields, full-cloud disclosure, pricing source, OpenAI processing/deletion terms, and privacy-owner sign-off.

**Acceptance checkpoint:** Fixture-backed runs prove local, sanitized-cloud, and full-cloud route disclosure; no selected-route failure falls back to cloud; cancellation produces no provider call; ledger entries retain route, completion state, linked record, and pricing version without raw sensitive prompts; and budget handling is deterministic.

### Workstream H — Connected Gmail and Calendar (Phase 2b)

**Objective:** Add permissioned Gmail and Calendar only after the privacy/AI routing and ledger foundation is accepted.

**Slices (in dependency order):**

1. Settings, connection lifecycle, separate OAuth scopes, encrypted token storage, disconnect/deletion controls, and permission-denied recovery.
2. Gmail selected-thread or opt-in-label synchronization, proposed matching with accept/reject memory, and thread linking.
3. Confidence-scored Gmail response classification with supporting thread evidence; high-confidence follow-up task proposals still require user acceptance, while low-confidence/ambiguous results route to manual review without task creation.
4. Draft creation plus exact-message review and distinct final-send confirmation, including recipients, subject, body, thread, routing/execution path, and send-result identifier recorded locally.
5. Calendar availability/conflict display and proposed interview-event create/update; commit only after explicit confirmation.

**Dependencies:** Workstream G acceptance; decisions on Gmail scope and Calendar behavior; OAuth app configuration; privacy/security approval.

**Acceptance checkpoint:** Simulated provider responses prove least-privilege scopes; rejected thread matches are not re-proposed without new evidence; high- and low-confidence classification fixtures show evidence and route correctly; no follow-up task is created before acceptance; Gmail never sends before final review confirmation; Calendar never changes an event before its own confirmation.

### Workstream I — Documents and research (Phase 2c)

**Objective:** Add full document processing/versioning and sourced research after the privacy/AI and connected-workflow foundations.

**Slices (in dependency order):**

1. Immutable document originals, master documents, DOCX variants, revision history, reviewable suggestions, final-file tracking, and DOCX/PDF export/reference semantics.
2. Research and employer intelligence with permitted sources; fact/anecdote/inference labels; source/date/confidence; and per-action use of the accepted routing and ledger contracts.

**Dependencies:** Workstreams G and H acceptance; approved provider/license list and source policy.

**Acceptance checkpoint:** Document revisions preserve source hashes, immutable provenance, and final-file linkage. Research conclusions retain source/date/category/confidence and the accepted route/ledger evidence without raw sensitive prompts stored by default.

### Workstream J — Decision support (Phase 3)

**Objective:** Add interview-preparation/call-review and offer-decision workflows built on the same local record, evidence, consent, and audit infrastructure.

**Slices (in dependency order):**

1. Prep Brief with sourced context, requirements mapping, talking points, practice prompts, and questions.
2. Transcript import and consented audio flow; independently deletable transcript/audio storage; recap, commitments, and follow-up generation.
3. Evidence-backed coaching rubric with visible inputs and `not enough evidence` outcome.
4. Offer capture, user-controlled weights, transparent comparison, missing-term flags, sensitivity display, and negotiation draft review.

**Dependencies:** Accepted Phase 2c, including Workstream G privacy/AI ledger capabilities; product-owner decisions on scoring weights/rubrics; consent and retention policy for recordings/transcripts.

**Acceptance checkpoint:** Change one offer weight and verify recomputation/explanation is predictable. Feed insufficient interview evidence and verify no fabricated score appears. Delete an interview transcript/audio and verify the interview record remains with the expected deletion activity event.

## Historical build sequence and future milestones

The M0–M5 work below describes how the MVP was planned and built. It is retained for traceability only; use **Current release status** above for what is shipped and what comes next.

| Milestone | Included workstreams | Demonstrable outcome | Gate to proceed |
| --- | --- | --- | --- |
| M0 — Product and architecture readiness | A design/architecture decisions | Reviewed domain, audit, privacy, state, and migration contracts; test fixtures identified | Historical — complete |
| M1 — Local record spine | A + first B slice | Persisted opportunity plus auditable activity timeline and recoverable states | Historical — complete |
| M2 — Daily tracker | B | Offline opportunity workspace, pipeline, next actions, and deterministic Needs attention loop work together | Historical — implemented in shipped MVP |
| M3 — Contacts and interactions | C | Offline contacts, interactions, and opportunity links work together | Historical — implemented in shipped MVP |
| M4 — Safe bulk capture | D | Import map/validate/duplicate-choice/report flow has no silent overwrite | Historical — implemented subset in shipped MVP |
| M5 — Reconciliation, MVP hardening, and release readiness | E + F | Evidence-to-decision reconciliation, lifecycle/export boundaries, accessibility, and release readiness satisfy the local MVP criteria | Historical — implemented subset in shipped MVP; Post-MVP refinement is the active planned phase |
| M6 — Privacy and AI foundation | G | Accepted routing, consent, local ledger, and budget contracts before any AI feature or connected workflow | Future — not started |
| M7 — Connected workflow | H | Permissioned Gmail/Calendar workflow, confidence/manual-review classification, accepted follow-up tasks, and explicit approvals | Future — not started |
| M8 — Documents and research | I | Full document versioning and sourced AI/research workflow | Future — not started |
| M9 — Decision support | J | Evidence-backed interview and offer support | Future — not started |

## Explicit decision gates

| Gate | Decision owner(s) | Decision required before | Decision criterion |
| --- | --- | --- | --- |
| Local data lifecycle | Product owner + privacy owner + tech lead | M0/M1 | Encryption posture, backup/export, default retention, deletion semantics, and recovery expectations are explicit. |
| Tracker semantics | Product owner + UX + tech lead | M2 | Initial stages, task/reminder rules, deterministic queue ordering, record deletion/archive behavior, and status history semantics are specified. |
| Import policy | Product owner + tech lead | M4 | Duplicate signals, candidate rationale, allowed update fields, reversibility behavior, and invalid-row handling are specified. |
| Reconciliation policy | Product owner + security/legal + tech lead | M5 | Allowed sources/request behavior, classification/evidence thresholds, retry behavior, and human closure confirmation are approved. |
| AI routing and ledger policy | Product owner + privacy/security + AI owner | M6 | Local runtime capability, sanitization fields, full-cloud disclosure copy, OpenAI terms/retention, pricing/budget behavior, and ledger redaction/search are approved. |
| Integration consent | Product owner + privacy/security + integration owner | M7 | Gmail scope (selected threads/label versus broader search), classification confidence/manual-review thresholds, follow-up task acceptance behavior, Calendar scope/conflict behavior, token lifecycle, and disconnect/deletion behavior are approved. |
| AI data and source policy | Product owner + privacy/security + AI owner | M8 | Approved sources/providers and user-provided evidence labeling are approved for research use on the already-accepted routing/ledger foundation. |
| Decision-rubric policy | Product owner + UX + AI owner | M9 | Offer/interview/employer weight/rubric inputs, `not enough evidence` thresholds, and explanation behavior are approved. |

If a gate is unresolved, the dependent slice may proceed only with a clearly isolated interface and fixture-backed placeholder behavior that cannot expose data, call a provider, or create irreversible user-visible state.

## Risks and mitigations

| Risk | Consequence | Mitigation / early signal |
| --- | --- | --- |
| Building screens before the command/audit model | Inconsistent history and unsafe later integrations | Require every MVP mutation to use the shared command and activity-event path; review this at M1. |
| Local schema changes become destructive | User record loss or upgrade failure | Versioned migrations, fixture migration tests, an always-required verified transaction-scoped rollback snapshot, and rollback/recovery guidance. Offer backup/export before migration only when a separately enrolled recoverable backup already exists; do not create a retained pre-enrollment backup. |
| Ambiguous reconciliation is treated as closure | Incorrect opportunity status and lost follow-up | Enforce taxonomy and explicit closure confirmation in service/UI tests; fixtures include failures and changed pages. |
| CSV duplicate logic is opaque or overly aggressive | Fragmented records or accidental overwrite | Show match rationale and row-level decision; preserve raw import/report evidence; test re-import fixtures. |
| Scope expands into Phase 2 during MVP | Delayed usable release and compromised local-first quality | M5 scope is limited to tracker, contacts, CSV, manual attachment/hash support, reminders, conservative reconciliation, and an empty/read-only local AI ledger; AI execution, connected services, document processing, and research stay behind gates. |
| Consent is implemented as a global setting | Private content is sent without informed action-level consent | Treat settings as defaults only; automate tests for full-cloud disclosure and cancel/local alternatives before execution. |
| OAuth scopes or provider behavior are approved late | Rework or blocked connected release | Resolve the M7 integration gate before integration implementation; use adapters and simulated providers in the meantime. |
| Research sources violate terms or blur evidence types | Legal/trust failure | Approved provider registry; block unsupported automation; require source/date/category/confidence in the result contract. |
| Accessibility/error states arrive after feature completion | Daily workflows are unusable in non-happy paths | Include state matrix and keyboard checks in each slice’s definition of done, not only M5. |
| AI/connected work precedes privacy foundation | Unauthorized data transfer or unreconciled audit behavior | Require M6 routing/consent/ledger acceptance before M7 Gmail/Calendar or M8 AI research/document processing. |
| Cost ledger lacks pricing context | Misleading spend data and loss of user trust | In M5 provide only an empty/read-only local search surface; from M6 store mode, model, tokens when available, pricing version, completion state, and linked record while excluding raw sensitive content by default. |

## Definition of done for every vertical slice

A slice is done only when all of the following are true:

- The user-visible workflow is implemented against real local data, not mock-only state.
- Required domain records, relationships, validations, and migrations are in place.
- Mutations create the correct activity event, with affected-record links and enough context to audit the decision.
- Empty, loading, offline, permission-denied (if applicable), validation failure, operation failure, and success/recovery states are implemented.
- Keyboard focus, accessible labels, Escape cancellation where applicable, and non-color status cues are verified.
- Deterministic automated tests cover primary, failure, and boundary paths; fixture-based tests cover provider/check/import behavior rather than live services.
- UX review confirms the reviewed mockup’s safe interaction intent: visible evidence, clear user-owned next action, and explicit confirmation for irreversible/external effects.
- Security/privacy review has approved any data leaving the Mac, credential handling, or new retention/deletion behavior.
- Documentation includes the feature’s behavior, data effects, recovery guidance, and any bounded limitation.
- No unresolved P0 defect can cause silent data loss, hidden external execution, unauthorized cloud transfer, automatic send/calendar change/status closure, or inaccessible core workflow.

## Whole-product acceptance-test checkpoints

These checkpoints should be maintained as a living release suite. They test the requirements that must remain true as later work is added.

1. **Offline daily loop:** In a clean local workspace, add/import an opportunity, link a contact, set a next action, record an interaction, locate the record through search/filter, and clear the queue. No connection is required.
2. **Queue determinism and audit:** With a fixed clock and fixture data, the same queue order appears after relaunch. Complete, snooze, reschedule, and stage actions each produce exactly one appropriate activity event.
3. **Import safety:** Run malformed, mixed-validity, and repeat CSV fixtures. Mapping, validation, duplicate rationale, each row decision, import report, and no-unintended-duplicate behavior are all verifiable.
4. **Reconciliation safety:** Simulate confirmed, ambiguous, blocked, changed-URL, failed, and fully offline results. Only a user-confirmed, evidence-backed closure updates status; every other case routes to manual review with retained result data. The offline case makes no request, preserves the prior result, and creates retry/manual-review work.
5. **Record integrity:** From an opportunity, navigate to linked contacts, interactions, document links, task, and reconciliation evidence; from a contact, navigate to every linked opportunity. Links and timelines remain consistent after unlink/update operations.
6. **Accessibility and recovery:** Exercise tracker/import/reconciliation by keyboard only; verify visible focus and Escape behavior. Confirm status labels are understandable without color and that non-happy-path states provide a recovery action.
7. **Data lifecycle:** Upgrade a fixture database through migrations, export it, and execute approved deletion scenarios. Verify intended data remains, deleted data follows policy, and activity evidence is handled as specified.
8. **MVP ledger boundary:** Verify the M5 AI-usage ledger is locally searchable and explicitly empty/read-only, creates no network activity, and has no raw sensitive content.
9. **AI privacy and provenance (Phase 2a):** For local, sanitized-cloud, and full-cloud modes, verify mode disclosure, cancel path, field sanitization, full-cloud confirmation, no fallback, ledger fields, budget handling, and absence of raw sensitive prompt content by default.
10. **Connected workflow (Phase 2b):** With provider test doubles, prove separate Gmail/Calendar permissions, explicit thread match acceptance/rejection, confidence/manual-review classification, user acceptance before follow-up task creation, exact-message final confirmation before send, and explicit event confirmation before change.
11. **Documents and research (Phase 2c):** Verify document revision provenance/final-file linkage and research labels for facts versus anecdote versus inference, including source/date/confidence and ledger route evidence.
12. **Decision transparency (Phase 3):** Verify coaching produces `not enough evidence` when appropriate and offer weights and sensitivity change results predictably with an explanation.

## Handoff checklist for Codex implementation

- Start with M0/M1 contracts, then deliver a demonstrable slice in the stated sequence; do not create disconnected feature UI before its data, audit, and state behavior exist.
- Treat the PRD requirements and `docs/product/ux-design-review.md` as acceptance constraints. The eight files in `design/mockups/ux/` provide reference flows for Needs attention, import, opportunity record, contacts CRM, reconciliation, privacy settings, the activity/AI ledger, and Gmail correspondence review.
- Keep MVP scope local-only: no Gmail, Calendar, AI execution/document generation, automated research, or document processing/versioning is needed to pass M5; the AI ledger is empty/read-only and locally searchable.
- For every new future capability, extend the shared domain/audit/evidence/privacy contracts; do not bypass them with feature-specific history, consent, or status logic.
- At each milestone, attach the acceptance evidence and unresolved decision/risk status before asking for the next gate.
