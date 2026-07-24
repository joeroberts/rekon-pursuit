# UX design review — Rekon Pursuit

## Executive assessment

The existing mockups establish a calm, premium visual system, but they under-represent the product's central promise: a reliable personal operating record that never acts on uncertain or private information without the user's approval. They favor presentation-oriented cards over the dense, auditable work surfaces needed for a daily tracker. The revised concepts preserve the quiet, focused tone while making status, provenance, pending decisions, and the next safe action immediately legible.

## What is working

- Clear visual hierarchy, generous whitespace, and readable typography make the product feel personal rather than enterprise-heavy.
- Opportunity, contacts, pipeline, and settings have useful conceptual coverage and provide a good starting information architecture.
- Cards and side panels are appropriate for review and preparation moments, especially when paired with a persistent record context.

## Primary UX gaps and recommendations

| Priority | Gap | Risk | Design direction |
| --- | --- | --- | --- |
| P0 | No dedicated daily work queue | Users must hunt through pipeline views and miss follow-ups. | Make **Needs attention** the default home: grouped, deterministic, and action-forward. Complete, snooze, reschedule, and open must preserve an activity entry. |
| P0 | Reconciliation results lack an explicit evidence-to-decision path | A failed check or changed URL may be mistaken for a closure signal. | Use result classes (`confirmed`, `ambiguous`, `failed`) with timestamp, URL, evidence/error, and a deliberate closure confirmation. Never offer automatic closure. |
| P0 | Import is presented as capture rather than a decision workflow | Duplicate imports can silently fragment the user's record or overwrite intentional edits. | Design CSV as a four-step flow: map, validate, compare each duplicate field-by-field, then explicitly commit the reviewed batch. The report must distinguish creates, selected field updates, skips, and validation failures; undo is available only while no later edits touch the batch. |
| P0 | Cloud-AI consent is too easy to bury in Settings | Users could misunderstand what content leaves their Mac. | Put routing and a content disclosure at the action point; Settings controls defaults/budgets, not consent. Full cloud always requires a distinct confirmation. |
| P1 | Opportunity detail reads as a summary instead of a working record | Notes, contacts, documents, and proof become disconnected across screens. | Use a persistent record header with stage, next action, job source/description, activity, people, documents, and reconciliation evidence in one navigable workspace. |
| P1 | Contact intelligence privileges research over relationship memory | The CRM cannot easily answer “who can help with this role?” | Center the contact timeline, relationship notes, and many-to-many opportunity links. Label research as sourced fact/inference separately. |
| P1 | Activity log and AI cost ledger are not first-class | Auditability and spend control are requirements, not secondary details. | Offer a searchable, filterable ledger with separate activity and AI-cost views. AI rows expose feature, linked opportunity, route, model, pricing version, usage/cost, and approval outcome—never raw prompts, notes, or document content by default. Link it from Settings alongside the budget meter. |
| P1 | Email correspondence has no review-to-action surface | A useful follow-up can be missed, while an inferred intent or draft might be mistaken for a sent reply. | Review each locally stored message with a suggested response type, confidence, and evidence. Let the user correct the classification, optionally create a follow-up task, and review a local draft before a separate handoff and final send confirmation. |

## Revised interaction model

1. **Daily loop:** capture/import → choose stage and next action → log the interaction → clear the Needs attention queue.
2. **Decision-safe automation:** every automation exposes its input, result/evidence, and the next user-owned decision. Ambiguous or failed states route to manual review.
3. **Working records:** opportunities and contacts retain linked history rather than hiding it in isolated feature screens.
4. **Privacy in context:** local is the default; sanitized cloud and full cloud show what changes in quality and what leaves the device before execution. Settings expose routing policy, budget, and history, but never pre-authorize an action: sanitized cloud requires an action-point disclosure and full cloud requires a separate explicit confirmation.
5. **Correspondence review:** Gmail messages are treated as local correspondence records after import. Suggestions are assistive, never authoritative: show the supporting excerpt and confidence; retain the original classification and a correction activity when the user changes it. Drafting creates a local draft first; sending is a handoff to Gmail followed by a final, per-message confirmation.
6. **Offline reconciliation:** reconciliation always shows the timestamp and status of the last locally saved result. If a new check cannot run (for example, offline), show **New checks unavailable** without changing any opportunity; retain the cached evidence and offer retry when connectivity returns. A failed check remains a source failure, never evidence of closure.

## Accessibility and interaction notes

- Do not rely on color alone: each status includes a text label and icon/shape.
- Keep keyboard focus visible; action menus should have plain-language labels and `Esc` cancellation.
- Use actual dates/times plus relative time where useful (for example, “Today, 2:00 PM”).
- Confirmation dialogs should state the irreversible effect, the affected records, and an alternative safe action.
- Empty, offline, permission-denied, and failed states need the same clear recovery guidance as happy paths. Cached local data must be identified separately from an unavailable new check.

## Artifacts

The eight browser-openable prototypes in `design/mockups/ux/` illustrate the recommended core flows: `needs-attention.html`, `opportunity-record.html`, `contacts-crm.html`, `import-opportunity.html`, `reconciliation-review.html`, `settings-privacy.html`, `activity-ai-ledger.html`, and `gmail-correspondence-review.html`. `import-opportunity.html` shows mapping through safe batch undo; `activity-ai-ledger.html` shows the searchable activity and AI-cost record; `gmail-correspondence-review.html` shows locally reviewed correspondence through final Gmail send confirmation. They are deliberately self-contained and use fictional local data only. Controls demonstrate the intended state transitions; they do not call services or transmit data.
