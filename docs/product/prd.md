# Rekon Pursuit

**Product requirements brief**  
**Product:** Rekon Pursuit by RekonLabs  
**Status:** Approved for roadmap and architecture handoff  
**Date:** July 23, 2026

## Product thesis

Job searching is fragmented across job boards, spreadsheets, email, calendars, documents, and memory. This local Mac app creates one private workspace to manage the end-to-end search, while using AI for research, preparation, drafting, and decision support.

**North-star outcome:** A user can understand their current search, confidently prepare for the next interaction, and take the right follow-up action from one place.

**Confirmed product boundary:** The product is a native-window Mac app distributed as a DMG. It is local-first, uses a local database, and connects to cloud services only when the user explicitly enables a connection or AI execution mode.

## User and problem

The primary user is an individual job seeker managing multiple opportunities, relationships, interviews, offers, and tailored application materials.

Today, they struggle to:

- Keep a reliable record of opportunities, stages, responses, and next actions.
- Remember who they have met, what was discussed, and where a person can help.
- Reconcile whether applications are still open.
- Coordinate job-search email and calendar logistics.
- Tailor materials and prepare for interviews without losing prior versions.
- Compare offers, employer quality, and negotiation options with confidence.

## Goals

- Maintain complete, searchable records of opportunities, contacts, interactions, materials, interviews, and offers.
- Reduce manual entry with CSV import and permissioned Gmail / Google Calendar connections.
- Use AI to provide editable, source-linked recommendations instead of unexplained conclusions.
- Support critical moments: applying, interviewing, following up, evaluating employers, and choosing or negotiating an offer.

## Guardrails and non-goals

- The app never sends email, changes a calendar, submits an application, or changes an opportunity status without user confirmation. Email sending requires a distinct final confirmation after the user has reviewed the exact recipient, message, and thread.
- It does not scrape restricted review or professional-network sites. It uses permitted/licensed sources and user-provided links or excerpts.
- AI scores are coaching and decision-support aids, not legal, tax, financial, employment, or factual guarantees.
- Private-content AI defaults to a local model. Cloud AI is an explicit per-action choice; the app must never silently fall back to cloud execution.
- When cloud AI is selected, the app offers a sanitization mode that removes configured identifiers before transmission and clearly explains the expected quality/privacy tradeoff.
- Full, unsanitized cloud AI is available only after a distinct per-action confirmation that identifies the data leaving the Mac. The user may cancel or choose local/sanitized execution instead.
- The first release serves one individual; it is not a recruiting team tool or social network.

## Core product experience

| Moment | User need | Product response |
| --- | --- | --- |
| Daily triage | Know exactly what needs a decision today. | Default **Needs attention** queue for overdue/upcoming tasks, interview prep, follow-ups, reconciliation reviews, and offer deadlines; each item has complete, snooze, reschedule, and open actions. |
| Capture | Add many leads without retyping. | CSV import with column mapping, validation, duplicate detection, preview, and import report. |
| Manage pipeline | Know what is active and needs attention. | Board and table views, customizable stages, responses, deadlines, follow-ups, and posting-status reconciliation. |
| Build relationships | Remember people and make network data useful. | Contact CRM linked to employers, roles, meetings, correspondence, notes, and opportunity discovery. |
| Apply | Tailor strong materials without losing versions. | Master résumé / cover-letter library, role-specific variants, change review, final-file tracking, and export. |
| Interview | Prepare with relevant, credible talking points. | Role and company brief, experience-to-requirement mapping, practice prompts, interview notes, and transcript/audio coaching. |
| Decide | Compare offers and find negotiating leverage. | Offer terms capture, user-weighted comparison, transparent evaluation, missing-term flags, and editable negotiation drafts. |

## Functional requirements

### Opportunity tracker and bulk import

- Create, edit, filter, and stage opportunities. Track the job URL, compensation, location, status, responses, dates, notes, and next action.
- Make Needs attention the default daily home. Order items deterministically by urgency/due date and create a local activity entry for every complete, snooze, reschedule, or status action.
- Import jobs through a required workflow: **map columns → validate rows → decide duplicates row-by-row → import → review report**. No duplicate is created or an existing record overwritten without a user choice.
- Add a **Reconcile openings** workflow that evaluates active job URLs and shows `Still open`, `Possibly closed`, or `Closed` with evidence. No opportunity is closed automatically due to a transient error or ambiguity.
- Define a clear daily workflow: **add/import → set stage and next action → record an interaction → work the Needs attention queue**.
- Make the opportunity record the canonical working record: editable stage and next action, job URL/description, notes and activity, people, document links, reconciliation evidence, and timeline in one navigable workspace.
- Reconciliation retains URL, timestamp, classification (confirmed, ambiguous, failed, or offline-unchecked), evidence/error, and confidence. Blocked, changed, failed, and offline-unchecked checks remain manual-review states; when offline, no check runs, the prior result remains visible, and retry/manual-review work is created. Closure requires explicit confirmation.
- Treat a blocked page, an inaccessible source, or a changed URL as `Needs manual review`, not evidence that a role closed. Store the URL, check timestamp, outcome, and evidence/error with every result.

### Contacts and networking

- Store reusable contacts with employer, title, email, profile link, relationship context, notes, meetings, and correspondence.
- Support contacts who are not yet associated with a job opportunity.
- Link a contact to multiple opportunities and surface relevant contacts when a role exists at their employer.
- Provide CRM basics: search/filter, relationship notes, interaction history, last/next touch, and explicit link/unlink actions for opportunities.
- Allow the user to request professional research briefs: role, background, public writing/talks, possible outreach angles, and referral relevance. Every item must show its source/date and distinguish fact from inference.

### Gmail and Google Calendar

- Connect Gmail for selected correspondence synchronization, opportunity/thread matching, response classification, and follow-up task proposals. Classifications and proposed tasks show a confidence level and supporting thread evidence; low-confidence or ambiguous results always require manual review, and no task is created until the user accepts it.
- Create Gmail drafts or proposed reply messages for user review. The app may send only after a distinct final confirmation; it never sends automatically.
- Before a send, display the exact recipient(s), subject, message body, linked thread, and selected execution path. Record the send confirmation and resulting message/thread identifier in the activity log.
- Connect Google Calendar independently to read availability and propose/create/update interview events after user confirmation.
- Attach event details, attendees, meeting links, prep material, reminders, and post-interview actions to the relevant opportunity.
- Start with explicit thread selection or an opt-in Gmail label. A user can accept or reject every proposed thread match, and rejected matches are not re-proposed without new evidence.

### Résumés and cover letters

- In the MVP, support DOCX and PDF only as manually attached local references, with source-file hashes and final-version-sent metadata. The MVP does not ingest, edit, transform, version, or export either format.
- In Phase 2, add immutable originals, reusable master résumés / cover letters, full document processing, DOCX variants, revision history, reviewable suggestions, final-file tracking, and DOCX/PDF export/reference semantics. Google Docs may be an optional, user-approved export/sync destination, but it is not the source of truth for document versions.
- Create job-specific variants from a base document and the job description.
- Show suggested changes for review, preserve a revision history, and record the exact final version sent for each application.
- Maintain a reusable library of approved experience bullets, accomplishments, skills, and cover-letter sections.

### Interview preparation and call review

- Create a role-specific Prep Brief: sourced company context, job requirements, likely interview themes, relevant user experience, talking points, practice questions, and smart questions to ask.
- Accept a transcript or a consented audio recording after an interview.
- Produce a recap, commitments, follow-ups, evidence-based coaching, and rubric scores for clarity, relevance, structure, confidence, and use of experience.
- Treat scores as coaching feedback, not objective assessments; provide the underlying evidence.

### Employer intelligence

- Generate an employer brief from permitted sources: careers/newsroom pages, public reporting, public-company filings, relevant government notices, and user-provided review excerpts or links.
- Separate verified facts, anecdotal signals, and AI inferences; include source, date, and confidence for each conclusion.
- Highlight recurring themes: stability, management/culture, workload, compensation, leadership changes, layoffs, and role-specific risk.
- Do not automate collection from Glassdoor or LinkedIn. User-provided excerpts are analyzed, labeled, and kept distinct from verified public sources.

### Offer comparison and negotiation

- Capture base salary, bonus, equity, vesting, sign-on, benefits, PTO, title/level, work arrangement, start date, location, deadlines, and conditions.
- Compare multiple offers using user-controlled weights for both financial and non-financial priorities.
- Explain the score, assumptions, missing information, and sensitivity to changing a weight.
- Identify negotiation priorities and draft a professional negotiation message for review.

### Activity logs, AI usage, and cost controls

- Keep a first-class activity log for imports, edits, stage/status changes, tasks, reconciliation checks, document versions, integration actions, and user approvals.
- Keep an AI usage ledger for each request: task/feature, execution mode (local, sanitized cloud, or full cloud), model, timestamp, completion state, input/output/cached-token counts when available, cost estimate, and related record.
- Do not retain raw prompts or sensitive email/transcript content in the usage ledger by default.
- Show daily and monthly cloud cost, cost by feature and opportunity, configurable budgets/alerts, and the pricing version used for each historical estimate.
- Track local-model requests separately as compute/runtime usage; do not represent them as a cloud API charge.
- Provide searchable activity-log and AI-usage views. A ledger entry links to the affected record, routing mode, completion state, and pricing version while excluding raw sensitive prompt content by default.
- The MVP includes an empty, read-only, locally searchable AI-usage ledger so the required search surface and privacy boundary are real before any AI execution exists. It must clearly state that no AI requests have run; it creates no entries, costs, prompts, or network activity. AI execution, routing choices, budgets, and populated entries begin only after the Phase 2 privacy/AI foundation is accepted.

## Interaction and state rules

- All controls require explicit loading, empty, offline, permission-denied, failed, and successful states; recovery guidance is visible in every non-happy-path state.
- Status must never depend on color alone. Use plain-language labels and a non-color cue; expose keyboard focus, Escape-to-cancel where applicable, and accessible action labels.
- Settings establishes defaults, budgets, sanitization fields, and retention policy. It does not substitute for an individual action's local/sanitized-cloud/full-cloud disclosure and consent.
- Every automation presents its input, result/evidence, and the next user-owned action. Ambiguous or failed automation outcomes route to manual review.
- Confirmation dialogs identify the affected record, irreversible effect, and a safer alternative when one exists.

## Data model

Core records: **Opportunity**, **Employer**, **Contact**, **Interaction**, **Task/Reminder**, **Document Version**, **Attachment/Document Link**, **Interview**, **Offer**, **Research Item**, **Job Posting Check**, **Import Batch**, **Opportunity Status History**, **Activity Event**, and **AI Usage Entry**.

An opportunity can have many contacts, interactions, tasks, interviews, document versions, research items, posting checks, activity events, and offers. A contact can link to several opportunities and employers over time. Every import, reconciliation, approval, and external execution is traceable to a local activity event.

## Integrations and permissions

| Integration | Purpose | Required control |
| --- | --- | --- |
| Gmail API | Read selected mail, locate threads, create drafts, and send user-confirmed messages. | Separate least-privilege read and compose/send scopes; an exact-message review and final send confirmation are mandatory; disconnect and deletion controls. |
| Google Calendar API | Read availability and create/update confirmed interview events. | Separate calendar scope; never create or change an event without review. |
| OpenAI API | Research synthesis, drafting, tailoring, transcription/review, and decision support. | Editable output, source/evidence visibility, and a clear retention/privacy policy. |
| Local model runtime | Private on-device AI for sensitive content and offline-capable workflows. | Default route for private data; clear availability/capability status and no silent cloud fallback. |
| Permitted web/data providers | U.S.-focused employer research, job availability, public-company data, WARN notices, and news monitoring. | Use official, licensed, or user-provided data; show source/date and honor provider terms. |

## Trust, privacy, and quality requirements

- Local-first storage by default; cloud processing is clearly disclosed and opt-in where required.
- OAuth tokens are encrypted at rest. Email and calendar connections can be revoked separately.
- Model routing is visible before execution, including local, sanitized-cloud, and full-cloud modes. The app explains what will leave the Mac and permits cancellation.
- Sync controls begin with selected queries/labels and show exactly which emails are linked to the tracker.
- Uploaded recordings prompt the user to verify appropriate consent. Transcript/audio deletion is independent of the interview record.
- Every AI conclusion shows evidence, date, confidence, and whether it is a fact, anecdotal signal, or inference.

## Recommended rollout

### MVP: reliable daily tracker

Local job tracker, pipeline, contacts, CSV import, manually attached DOCX/PDF references with hashes, follow-up reminders, conservative job-posting reconciliation, and an empty/read-only local AI-usage ledger. The MVP does not require Gmail, Calendar, AI execution or document generation, automated research, or document processing/versioning.

**MVP success criteria**

- A user can add/import an opportunity, link a contact, set a next action, and find it through filter/search in under two minutes.
- Re-importing the same CSV produces no unintended duplicates; the duplicate rationale is visible.
- Every reconciliation result records URL, timestamp, evidence/error, and status; suggested closures always require confirmation. Fully offline reconciliation performs no check and preserves the prior result; it shows `Offline — check not run`, keeps the opportunity active, creates a retry/manual-review item, and never infers closure.
- The Needs attention view deterministically shows overdue and upcoming actions.
- A user can complete, snooze, reschedule, or open every Needs attention item, with the action recorded locally.
- A user can search/filter activity entries and the empty/read-only AI-usage ledger by time, feature, related opportunity, execution route, model, completion state, and cost range without exposing raw sensitive prompt content.

### Phase 2a: privacy and AI foundation

Model-route selection, sanitization/full-cloud disclosure, local-only execution failure handling, local AI-usage ledger writes/search, pricing versions, budgets, and consent/audit tests. No AI feature ships before this foundation is accepted.

**Phase 2a quality bar:** local, sanitized-cloud, and full-cloud routes are visibly distinct; selected-route failure never falls back to cloud; every execution produces an appropriately redacted local ledger entry; and no network call occurs without the route’s required disclosure/confirmation.

### Phase 2b: connected workflow

Gmail and Google Calendar after the privacy/AI foundation. Gmail includes selected-thread/label sync, match review, confidence-scored response classification, and user-accepted follow-up task generation; Calendar includes availability and confirmed mutations.

**Phase 2b quality bar:** Gmail never sends automatically and requires exact-message review plus final confirmation before any send; low-confidence or ambiguous classifications are manual-review-only and proposed follow-up tasks require acceptance; Calendar shows conflicts before proposing a change.

### Phase 2c: documents and research

Full document processing/versioning and sourced AI research/employer intelligence follow the privacy/AI foundation and connected workflow.

**Phase 2c quality bar:** document revisions preserve immutable provenance and final-file linkage; all research claims include source, date, evidence category, and confidence.

### Phase 3: decision support

Interview preparation, transcript/recording coaching, offer comparison, negotiation planning, and deeper analytics.

**Phase 3 quality bar:** scores expose user-visible rubric inputs, support a `not enough evidence` state, and update predictably as weights change.

## Open PM decisions

- **Resolved local-data policy:** [ADR-001](../architecture/adr/ADR-001-local-data-lifecycle.md) and the [M0-2 lifecycle contract](../architecture/local-data-lifecycle-contract.md) govern indefinite active-data retention, immediate logical deletion, opt-in recoverable backups expiring 30 days after creation, explicit backup purge, encrypted-default export, and warned/reviewed unencrypted export. These are implementation requirements, not open PM decisions.
- OpenAI processing terms.
- Gmail scope: selected job correspondence vs. broader mailbox search.
- Google Calendar initial scope, reminders, and conflict-resolution behavior.
- User-configured score weights and rubrics for offers, interview feedback, and employer risk.
- Approved web/news providers, source licensing, refresh cadence, and labeling for user-supplied evidence.

## Research constraints noted

Gmail and Google Calendar are separate APIs with separate OAuth permissions. Public-company filings are available through [SEC EDGAR](https://www.sec.gov/search-filings), and certain large layoffs are covered by [WARN requirements](https://www.dol.gov/index.php/general/topic/termination/plantclosings). Glassdoor and LinkedIn prohibit unauthorized automated scraping, so review/profile inputs must come from permitted integrations, licensed providers, public pages, or material supplied by the user: [Glassdoor terms](https://www.glassdoor.com/about/terms-2020-07-08/), [LinkedIn policy](https://www.linkedin.com/help/linkedin/answer/a1341387/prohibited-software-and-extensions).
