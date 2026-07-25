# RP-DASH-001 — Local delivery dashboard

**State:** Pending plan gate  
**Depends on:** Approval by Architect, TPM, QA, and Delivery Manager  
**Blocks:** Nothing in the macOS product roadmap

## Outcome

Provide one local, static, always-readable delivery dashboard that presents
the active remediation queue without introducing another source of delivery
truth. It opens directly from the repository in a browser, needs no server,
database, cloud account, Node runtime, or installed package, and refreshes
itself every 30 seconds.

This is repository delivery tooling. It is not a Codex plugin and is not part
of the SwiftUI/macOS application.

## Authority and state contract

- `docs/delivery/dashboard-status.json` is the **one canonical,
  machine-readable operational status view**. It is versioned with the
  repository.
- `docs/delivery/remediation-ledger.md` remains the detailed audit and
  evidence record. A meaningful delivery transition updates the JSON and the
  applicable ledger entry together, then regenerates the dashboard in that
  same delivery update.
- The dashboard is a projection of those records, never an independent
  roadmap. It must display the task IDs and state exactly supplied by its JSON
  input; the renderer must not infer acceptance from a commit, a test result,
  or prose in another document.
- The Delivery Manager records the product-owner-directed **dashboard
  operational baseline** in the ledger before the first generated dashboard.
  The original seed was superseded by a same-day product-owner correction:
  accepted R2 evidence must not be represented as pending verification.
  The current operational state is `RP-R0`, `RP-R1a`, `RP-R1b`, and `RP-R2`
  Accepted; `RP-R3` Next up; `RP-R4` through `RP-R10` Backlog; and an empty
  Blocked lane unless a genuine material impediment subsequently appears.
  `dashboard-status.json` controls current task transitions and the ledger
  records their detailed audit/evidence; neither may be updated alone.

## Data shape

The JSON schema is deliberately small and renderer-oriented:

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-07-25T00:00:00Z",
  "activeTaskId": "RP-R2",
  "nextEligibleTaskId": "RP-R3",
  "tasks": [
    {
      "id": "RP-R2",
      "title": "Corrective pass / verification required",
      "status": "in_progress",
      "releaseCondition": "Product-owner verification required",
      "latestTransition": "Corrective pass entered verification",
      "evidence": { "label": "R2 evidence", "href": "../evidence/..." },
      "needsUserAction": true,
      "userActionDetail": "Verify the isolated workflow"
    }
  ]
}
```

`evidence` and `userActionDetail` are optional. `needsUserAction` is required
for every task and is true only for a material product decision, hands-on
verification, or intervention; `userActionDetail` is required when true.
The renderer displays **No action needed** when false. Evidence paths are
relative repository-local links only: the renderer rejects absolute paths, URI
schemes, and paths that traverse outside the repository. The allowed status
values are exactly `backlog`, `next_up`, `in_progress`, `accepted`, and
`blocked`. Reject an unknown status rather than placing it in an arbitrary
lane.

## UI and rendering contract

- Add a deterministic repository-local renderer (shell/Python/Ruby already
  available on macOS, or a checked-in browser-only renderer) and generate
  `docs/delivery/dashboard/index.html`. Do not add a package manager,
  dependency, runtime service, or external fetch.
- The committed HTML must work via `file://` when opened in a browser. It may
  contain the rendered state directly, so it does not rely on browser file
  fetch permissions. Include `meta http-equiv="refresh" content="30"` (or an
  equivalent browser-local reload) so an open tab reloads every 30 seconds.
- Use the approved dark Rekon base. Lanes appear horizontally in this exact
  order: **Backlog**, **Next up**, **In progress**, **Accepted**, **Blocked**.
  On a narrow viewport they may scroll horizontally, but their order cannot
  change.
- Apply restrained, scannable state color only: amber backlog; violet next up;
  Rekon cyan/blue in progress; muted emerald accepted; red/coral blocked.
  Blocked is reserved for a material decision, missing authority, external
  dependency, or failed prerequisite requiring intervention. Ordinary queued
  sequencing is Backlog, not Blocked.
- Every task is one card and shows: ID/title, status, dependency or release
  condition when present, latest meaningful transition, evidence/commit link
  when present, and whether the user must act.
- The top summary displays active task, next eligible task, accepted count,
  backlog count, blocked count, and an attention queue. The attention queue
  derives only from `needsUserAction: true` plus its material action detail;
  it is empty otherwise. Routine tests, commits, generated files, and
  documentation updates never create attention.

## Maintenance workflow

Add a short repository-local instruction adjacent to the renderer (or in the
delivery directory) that states:

1. On a meaningful delivery transition only, update the relevant status,
   `latestTransition`, release condition, evidence link, and material
   `userAction` in `dashboard-status.json`.
2. Make the matching audit/evidence update in `remediation-ledger.md`.
3. Run the checked-in renderer to regenerate `dashboard/index.html`.
4. Open the generated HTML locally and confirm the displayed lane/counts,
   task card facts, links, and 30-second reload marker match the JSON.

The only normal transition path is **Backlog → Next up → In progress →
Accepted**. A task enters or leaves Blocked only for a real material
impediment/resolution. Routine chatter is not a transition and does not modify
the JSON, ledger, or generated page.

## Focused acceptance

1. With no service running and network disabled, opening
   `docs/delivery/dashboard/index.html` directly shows all five horizontal
   lanes in the required order, dark Rekon styling, and the seeded remediation
   cards in their prescribed lanes.
2. The summary counts and active/next labels exactly match the status JSON;
   the attention queue contains only explicit material `userAction` entries.
3. Each card presents all available required facts and its local evidence link
   resolves when evidence is supplied. Missing optional facts render as an
   intentional concise absence, not broken text or links.
4. The generated document includes a 30-second automatic reload mechanism;
   changing the JSON, regenerating the HTML, and waiting/reloading shows the
   changed state without a server.
5. The renderer is deterministic: unchanged JSON produces no meaningful HTML
   content change. Invalid JSON/status fails with an actionable local error
   rather than silently producing a misleading dashboard.
6. No SwiftUI app source, production data, cloud integration, database,
   plugin, background process, Node dependency, or CI expansion is added.

## Verification boundary

Use only focused local checks: parse/validate the JSON, run the renderer,
inspect generated HTML for the refresh marker and required lanes, and open the
file locally in a browser. QA must verify the state-authority and attention
semantics against the ledger; Architect must verify that local links and the
renderer add no data/network boundary; TPM and Delivery Manager must approve
the transition/update contract and the reconciled seed before implementation.
