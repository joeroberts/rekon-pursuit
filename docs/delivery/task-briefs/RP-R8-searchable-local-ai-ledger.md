# RP-R8 — Searchable local AI ledger

**State:** In progress — released only for the bounded MVP implementation  
**Depends on:** the full `RP-R7a` sequence and accepted `RP-R7b-1` only.  
`RP-R7b-2` retained-data purge/rebuild is explicitly **not** a dependency.  
**Blocks:** `RP-R9` and `RP-R10`

## User-visible outcome

The existing **Activity & AI** screen contains a clearly labeled, read-only
**AI usage ledger**. It truthfully says that no AI requests have run, while
still exposing a local filter surface for a future ledger: time, feature,
opportunity, route, model, completion state, and USD cost range. With zero
entries, changing or clearing a filter never creates a record, cost,
activity/audit event, network request, or AI request.

## Scope and boundaries

- Replace the current AI usage placeholder in `GlobalActivityView` with the
  empty ledger/filter surface. Preserve the existing, separate local activity
  search unchanged.
- Keep all filter state in the view only. It is deliberately not persisted
  across relaunch because it is not tracker data or a user preference.
- The Opportunity filter contains **All opportunities** plus the currently
  loaded local opportunities. It only selects a future filter value; it does
  not link, mutate, persist, log, or externally disclose an opportunity.
- Use the following fixed filter values without adding a model/provider
  catalogue:

  | Filter | MVP control / values |
  | --- | --- |
  | Time | All time, Last 24 hours, Last 7 days, This month |
  | Feature | Optional local text query |
  | Opportunity | All opportunities or one loaded local opportunity |
  | Route | Any route, Local, Sanitized cloud, Full cloud |
  | Model | Optional local text query |
  | Completion | Any completion, Completed, Failed, Cancelled, Blocked |
  | Cost | Optional minimum and maximum USD numeric inputs; blank means unbounded |

- Provide one **Clear filters** action that returns all controls to defaults.
  An incomplete or invalid cost range shows plain-language inline feedback and
  leaves the ledger empty; it never manufactures a zero-cost entry or coerces
  an entered value.
- The empty state is explicit: **“No AI requests have run.”** It states that
  local and cloud AI execution, model/runtime activity, and cost calculation
  are unavailable in this MVP. Filtered state also says zero entries match.

### Non-goals

- No `ai_usage_entries` table, database migration, persistence API, fixture,
  telemetry, metrics/cost aggregation, activity event, or audit event.
- No local model, cloud provider, model catalogue, route selection,
  sanitization, budget, pricing, prompt/content retention, or network call.
- No populated rows, synthetic example data in the product, export change,
  Settings change, app-dashboard/AI-feature work, or Phase 2 capability. The
  delivery dashboard and remediation ledger still change together at the real
  **Next up → In progress** release transition; that operational record is
  outside the app implementation surface.
- No change to the existing local activity ledger or its search behavior.

## Implementation shape and exact file surface

| File | Change |
| --- | --- |
| `RekonPursuit/AIUsageLedgerFilter.swift` | Create a small app-target-only `AIUsageLedgerFilter` value type and fixed time/route/completion enums. It owns defaults, the one cost-range validation rule, `isDefault`, and `reset()`; no store, database, provider, clock, or network dependency. |
| `RekonPursuit/ContentView.swift` | Replace the private `GlobalActivityView` AI placeholder with responsive read-only ledger controls and empty state. Bind local `@State`; use loaded opportunities only for the picker; add the identifiers below. |
| `RekonPursuit.xcodeproj/project.pbxproj` | Add the new Swift source file to the RekonPursuit application target only. |
| `RekonPursuitTests/RekonPursuitTests.swift` | Add deterministic unit tests for default/reset state and valid/invalid cost-range parsing. |

No file under `RekonPursuitCore/`, `RekonPursuitCoreTests/`,
`WorkspaceViewModel.swift`, database migrations, dashboard state, or the
remediation ledger is part of this task.

### UI contract

Controls appear below the local activity group in `Activity & AI`, inside one
compact `GroupBox("AI usage ledger")`. They remain usable at the current
minimum window size and wrap rather than clip. Use existing Rekon theme and
standard `Picker` / `TextField` controls; no dependency or bespoke chart.

Required accessibility identifiers:

- `ai-ledger-time-filter`
- `ai-ledger-feature-filter`
- `ai-ledger-opportunity-filter`
- `ai-ledger-route-filter`
- `ai-ledger-model-filter`
- `ai-ledger-completion-filter`
- `ai-ledger-min-cost-filter`
- `ai-ledger-max-cost-filter`
- `ai-ledger-clear-filters`
- `ai-ledger-empty-state`

## Test-first implementation tasks

1. **Define filter state before UI.** Add failing tests for default filter
   state; exact `reset()` behavior; blank, zero, and ordered non-negative USD
   bounds; and malformed, negative, and reversed cost-range errors. Implement
   only the pure filter type. Run the focused `RekonPursuitTests` cases.
2. **Render the real empty search surface.** Replace only the AI placeholder
   with controls and the explicit empty state. Bind every control locally,
   validate cost while editing, and make Clear filters restore defaults. Do
   not mutate the store/view model, append activity, or invoke an adapter.
3. **Verify the privacy boundary.** Run focused filter tests and the existing
   `RekonPursuitTests` target. In a signed Debug app at the minimum content
   size, change each control, enter a valid and an invalid cost range, clear
   filters, and use current macOS accessibility tooling to confirm every
   labeled control and the empty state are exposed. Confirm no cost,
   request/network, AI capability, or ledger entry appears. Do not add
   workspace-reset, fixture-launch, or test-only production plumbing for this
   zero-entry surface.

## Acceptance criteria

- Activity & AI has an explicit empty/read-only local AI ledger with all seven
  filter dimensions and Clear filters.
- Default and filtered states plainly say no AI requests have run; no retained
  or synthetic entry appears.
- Interactions are local-only with no database mutation, activity/audit event,
  metrics/cost calculation, model execution, or network behavior.
- Existing local activity search works unchanged.
- Invalid cost input is explained plainly and never becomes a cost value/entry.
- Focused unit evidence proves filter/reset/cost semantics; one signed Debug
  owner smoke covers all controls, labels, and the empty ledger at minimum
  content size.

## Release rule and risks

This brief is planning only. Planning, Architect, TPM, QA, and Delivery
Manager must approve this exact boundary before R8 moves from **Next up** to
**In progress**. A fresh code reviewer and QA verifier review the completed
slice before product-owner acceptance. Security/Privacy review confirms the
absence of AI execution, network calls, raw prompts/content, entries, and
cost telemetry; no AI routing policy is approved here.

The material risk is accidentally turning an empty filter UI into a simulated
or populated AI feature. The explicit non-goals, no-store file surface, and
focused smoke are the guardrail. Phase 2 owns real entry storage, redaction,
routing, pricing, budgets, and populated search behavior.
