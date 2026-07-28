# Unified Delivery Kanban Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Expand the static delivery dashboard into one phase-filterable Kanban board for accepted remediation history, active post-MVP work, and future product phases.

**Architecture:** Keep `docs/delivery/dashboard-status.json` as the canonical
machine-readable dashboard projection and the standard-library Python static
renderer. The remediation ledger remains detailed acceptance/evidence
authority, and `docs/delivery/roadmap.md` remains product sequencing authority.
Add phase metadata and validation, embed phase data into file-local HTML, and
use a DOM-only browser script to switch the displayed phase. Keep
`remediation.html` as the stable detail-file path, but make its copy
delivery-neutral.

**Tech Stack:** Python 3 standard library (json, html, unittest, tempfile), static HTML/CSS/vanilla JavaScript, versioned JSON and Markdown.

## Global Constraints

- No SQLite, server, cloud service, Node dependency, external fetch, browser database, plugin, or macOS-app change.
- The page must work from file://, include the existing 30-second refresh, and work without network access.
- Keep lane order/color/meaning: Backlog, Next up, In progress, Accepted, Blocked.
- A dependency is Backlog, not Blocked. Blocked means a material intervention requirement.
- Every task has a valid phase. A future remediation cycle is a distinct phase, never a silent addition to accepted Remediation R1.
- Start on activePhaseId; phase switching is view state only and may not write JSON, ledger, task state, attention state, URL state, or browser-persistent state.
- Counts, active/next text, attention, and cards describe only the selected phase.
- Do not alter accepted remediation facts or release a future card.

---

## File structure

| File | Responsibility |
| --- | --- |
| scripts/delivery/render_dashboard.py | Validate phases; render selector, selected-phase board/summary, DOM-only filter script, and delivery-neutral detail page. |
| scripts/delivery/test_render_dashboard.py | New standard-library contract/rendering regression suite. |
| docs/delivery/dashboard-status.json | Phase catalog, active phase, task phase membership, approved future cards. |
| docs/delivery/dashboard/index.html | Generated static unified board. |
| docs/delivery/dashboard/remediation.html | Generated detail page at the existing stable local path. |
| docs/delivery/dashboard/README.md | Phase-aware maintenance instructions. |
| docs/delivery/remediation-ledger.md | One detailed board-model expansion record; accepted R1 facts remain unchanged. |
| docs/delivery/task-briefs/DELIVERY-KANBAN-unified-phase-board.md | Durable delivery brief recording the approved dashboard-model boundary, exact scope, acceptance checks, and release prohibition for the planned cards. |
| docs/delivery/roadmap.md | Align post-remediation wording with the unified board while retaining detailed product sequencing. |

## Canonical phase/card contract

Add this exact ordered phase catalog and set activePhaseId to post_mvp_refinement:

~~~json
[
  {"id":"remediation_r1","label":"Remediation R1","lifecycle":"historical","dependsOnPhaseIds":[]},
  {"id":"post_mvp_refinement","label":"Post-MVP refinement","lifecycle":"active","dependsOnPhaseIds":["remediation_r1"]},
  {"id":"phase_2a","label":"Phase 2a — Privacy and AI foundation","lifecycle":"planned","dependsOnPhaseIds":["post_mvp_refinement"]},
  {"id":"phase_2b","label":"Phase 2b — Connected workflow","lifecycle":"planned","dependsOnPhaseIds":["phase_2a"]},
  {"id":"phase_2c","label":"Phase 2c — Intelligence and documents","lifecycle":"planned","dependsOnPhaseIds":["phase_2b"]},
  {"id":"phase_3","label":"Phase 3 — Decision support","lifecycle":"planned","dependsOnPhaseIds":["phase_2c"]}
]
~~~

`lifecycle` is exactly `historical`, `active`, or `planned`. There is exactly
one active phase and it must equal `activePhaseId`. Historical phase cards are
all Accepted. Planned phase cards are all Backlog and cannot require user
action. A phase can become active only after every `dependsOnPhaseIds` phase is
historical and all of its cards are Accepted. `activeTaskId` and
`nextEligibleTaskId`, if present, must belong to the active phase and have
`in_progress` and `next_up` status respectively. These checks are the
repository-controlled release gate; the browser selector never changes them.

Add phaseId: remediation_r1 to every existing task. Add these Backlog cards with needsUserAction: false:

| ID | Phase | Title | Work type |
| --- | --- | --- | --- |
| UX-D10 | post_mvp_refinement | Protected-export success confirmation polish | UX refinement |
| UX-D11 | post_mvp_refinement | Logs and AI Ledger tabs | UX refinement |
| UX-D12 | post_mvp_refinement | Refine local log-search semantics | UX refinement |
| DESIGN-V2 | post_mvp_refinement | Richer visual language and pipeline board experience | Product & UX |
| P2A-1 | phase_2a | Privacy and AI foundation | Privacy & AI foundation |
| P2B-1 | phase_2b | Connected Gmail and Calendar workflow | Connected workflow |
| P2C-1 | phase_2c | Intelligence and documents | Intelligence & documents |
| P3-1 | phase_3 | Decision support | Decision support |

Use the approved scope sentences from the design/roadmap for releaseCondition and latestTransition. P2B/P2C/P3 release conditions name prior phases as normal sequencing, not a Blocked state. Leave activeTaskId and nextEligibleTaskId null because nothing in the active phase is released.

### Task 1: Phase contract and standard-library test harness

**Files:**
- Create: scripts/delivery/test_render_dashboard.py
- Modify: scripts/delivery/render_dashboard.py: load_and_validate, render_detail_page

**Interfaces:**
- Consumes: a JSON object with schemaVersion, phases, activePhaseId, task phaseId, current task IDs, and tasks.
- Produces: load_and_validate(source: Path) -> dict that rejects invalid phase catalog, lifecycle, dependency, membership, and active-task data.
- Produces: script_safe_json(value: object) -> str that makes an application/json script payload safe by replacing `<`, `>`, `&`, U+2028, and U+2029 with JSON Unicode escapes.
- Produces: render_detail_page(status: dict) -> str with resolved phase label.

- [ ] **Step 1: Write failing contract tests**

Create import-by-file-path test scaffolding and minimal valid fixture:

~~~python
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

RENDERER_PATH = Path(__file__).with_name("render_dashboard.py")
SPEC = importlib.util.spec_from_file_location("render_dashboard", RENDERER_PATH)
renderer = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(renderer)

def valid_status():
    return {
        "schemaVersion": 1, "activePhaseId": "post_mvp_refinement",
        "activeTaskId": None, "nextEligibleTaskId": None,
        "phases": [
            {"id": "remediation_r1", "label": "Remediation R1",
             "lifecycle": "historical", "dependsOnPhaseIds": []},
            {"id": "post_mvp_refinement", "label": "Post-MVP refinement",
             "lifecycle": "active", "dependsOnPhaseIds": ["remediation_r1"]},
        ],
        "tasks": [
            {"id": "RP-R10", "phaseId": "remediation_r1", "title": "Acceptance",
             "workType": "Acceptance", "status": "accepted",
             "releaseCondition": "Accepted.", "latestTransition": "Accepted.",
             "needsUserAction": False},
            {"id": "UX-D11", "phaseId": "post_mvp_refinement", "title": "Tabs",
             "workType": "UX refinement", "status": "backlog",
             "releaseCondition": "Planned.", "latestTransition": "Queued.",
             "needsUserAction": False},
        ],
    }
~~~

Add a helper that writes json.dumps(value) to a temporary status.json and calls renderer.load_and_validate(source). Add these exact assertions:

~~~python
def test_rejects_task_with_unknown_phase_id(self):
    status = valid_status()
    status["tasks"][0]["phaseId"] = "unknown"
    with self.assertRaisesRegex(renderer.DashboardContractError, "phaseId"):
        self.validate(status)

def test_rejects_missing_task_phase_id(self):
    status = valid_status()
    del status["tasks"][0]["phaseId"]
    with self.assertRaisesRegex(renderer.DashboardContractError, "phaseId"):
        self.validate(status)

def test_rejects_active_phase_outside_catalog(self):
    status = valid_status()
    status["activePhaseId"] = "phase_2a"
    with self.assertRaisesRegex(renderer.DashboardContractError, "activePhaseId"):
        self.validate(status)

def test_rejects_duplicate_phase_ids(self):
    status = valid_status()
    status["phases"].append({"id": "remediation_r1", "label": "Duplicate"})
    with self.assertRaisesRegex(renderer.DashboardContractError, "Duplicate phase ID"):
        self.validate(status)

def test_rejects_planned_phase_with_released_task(self):
    status = valid_status()
    status["phases"].append(
        {"id": "phase_2a", "label": "Phase 2a", "lifecycle": "planned",
         "dependsOnPhaseIds": []}
    )
    status["tasks"].append(
        {"id": "P2A-1", "phaseId": "phase_2a", "title": "Foundation",
         "workType": "Foundation", "status": "next_up",
         "releaseCondition": "Planned.", "latestTransition": "Queued.",
         "needsUserAction": False}
    )
    with self.assertRaisesRegex(renderer.DashboardContractError, "planned"):
        self.validate(status)

def test_rejects_active_phase_with_unaccepted_dependency(self):
    status = valid_status()
    status["phases"][1]["dependsOnPhaseIds"] = ["remediation_r1"]
    status["tasks"][0]["status"] = "backlog"
    with self.assertRaises(renderer.DashboardContractError):
        self.validate(status)

def test_rejects_all_phase_lifecycle_invariant_failures(self):
    cases = []

    no_active = valid_status()
    no_active["phases"][1]["lifecycle"] = "planned"
    cases.append(("no active phase", no_active))

    unknown_dependency = valid_status()
    unknown_dependency["phases"][1]["dependsOnPhaseIds"] = ["missing"]
    cases.append(("unknown dependency", unknown_dependency))

    self_dependency = valid_status()
    self_dependency["phases"][1]["dependsOnPhaseIds"] = ["post_mvp_refinement"]
    cases.append(("self dependency", self_dependency))

    duplicate_dependency = valid_status()
    duplicate_dependency["phases"][1]["dependsOnPhaseIds"] = ["remediation_r1", "remediation_r1"]
    cases.append(("duplicate dependency", duplicate_dependency))

    cyclic = valid_status()
    cyclic["phases"][0]["lifecycle"] = "active"
    cyclic["phases"][0]["dependsOnPhaseIds"] = ["post_mvp_refinement"]
    cyclic["phases"][1]["lifecycle"] = "historical"
    cyclic["phases"][1]["dependsOnPhaseIds"] = ["remediation_r1"]
    cyclic["activePhaseId"] = "remediation_r1"
    cases.append(("cyclic dependency", cyclic))

    historical_not_accepted = valid_status()
    historical_not_accepted["tasks"][0]["status"] = "backlog"
    cases.append(("historical non-accepted task", historical_not_accepted))

    bad_active = valid_status()
    bad_active["activeTaskId"] = "UX-D11"
    cases.append(("active task status", bad_active))

    bad_next = valid_status()
    bad_next["nextEligibleTaskId"] = "UX-D11"
    cases.append(("next task status", bad_next))

    for name, status in cases:
        with self.subTest(name=name):
            with self.assertRaises(renderer.DashboardContractError):
                self.validate(status)

def test_script_safe_json_cannot_close_a_script_element(self):
    payload = renderer.script_safe_json({"title": "</script><img src=x>"})
    self.assertNotIn("</script", payload.lower())
    self.assertIn(r"\u003c/script\u003e", payload)
~~~

- [ ] **Step 2: Run to verify failure**

Run:

~~~bash
python3 -m unittest scripts/delivery/test_render_dashboard.py -v
~~~

Expected: FAIL because the current contract has no required phases, activePhaseId, or task phaseId.

- [ ] **Step 3: Implement minimal validation**

Before task validation, require a non-empty ordered phases list. Require every
phase object to have unique non-empty id/label, one valid lifecycle, and a
deduplicated dependency list containing only other declared phases. Reject
self-dependencies and dependency cycles. Require exactly one `active` lifecycle
phase and require it to equal `activePhaseId`. In the existing task loop add:

~~~python
phase_id = require_string(task.get("phaseId"), f"tasks[{index}].phaseId")
if phase_id not in phase_ids:
    raise DashboardContractError(
        f"tasks[{index}].phaseId {phase_id!r} does not match a phase."
    )
~~~

Keep current ID/status/action/evidence validation and preserve
`validate_local_href` as the sole evidence-link authority. Enforce lifecycle
rules after task membership validation: historical cards are Accepted; planned
cards are Backlog with no action; active/next IDs belong to the active phase
with their matching statuses; and every active phase dependency is historical
with only Accepted cards. Implement `script_safe_json` using `json.dumps` then
replace literal `&`, `<`, `>`, U+2028, and U+2029. In the detail renderer
resolve phase label, display it beside ID/work type/status, and change only the
visible heading to Delivery task details; preserve remediation.html and
fragment IDs.

- [ ] **Step 4: Verify**

Run:

~~~bash
python3 -m unittest scripts/delivery/test_render_dashboard.py -v
~~~

Expected: PASS.

- [ ] **Step 5: Commit**

~~~bash
git add scripts/delivery/render_dashboard.py scripts/delivery/test_render_dashboard.py
git commit -m "feat: validate delivery dashboard phases"
~~~

### Task 2: Static selector and selected-phase rendering

**Files:**
- Modify: scripts/delivery/test_render_dashboard.py
- Modify: scripts/delivery/render_dashboard.py: render_card, render_dashboard, render_detail_page

**Interfaces:**
- Consumes: validated phase-aware JSON from Task 1.
- Produces: local HTML with id="phase-selector", data-active-phase, server-rendered active-phase cards, phase labels, a script-safe payload, and an inline DOM-only filter script.
- Produces: selected-phase-only counts, summary, attention, lanes, and active/next wording.

- [ ] **Step 1: Write failing render-contract tests**

Add:

~~~python
def test_render_starts_on_active_phase_and_embeds_all_phases(self):
    page = renderer.render_dashboard(valid_status())
    self.assertIn('id="phase-selector"', page)
    self.assertIn('data-active-phase="post_mvp_refinement"', page)
    self.assertIn('value="post_mvp_refinement" selected', page)
    self.assertIn('id="dashboard-data" type="application/json"', page)
    self.assertIn('"remediation_r1"', page)
    self.assertIn('"post_mvp_refinement"', page)
    self.assertIn('Post-MVP refinement', page)

def test_render_initially_contains_only_active_phase_cards(self):
    page = renderer.render_dashboard(valid_status())
    self.assertIn('>Tabs<', page)
    self.assertNotIn('>Acceptance<', page)

def test_render_scopes_initial_summary_to_active_phase(self):
    page = renderer.render_dashboard(valid_status())
    self.assertIn('id="summary-accepted">0<', page)
    self.assertIn('id="summary-backlog">1<', page)
    self.assertIn('No task in progress', page)
    self.assertIn('No successor eligible', page)

def test_render_keeps_file_local_contract(self):
    page = renderer.render_dashboard(valid_status())
    self.assertIn('<meta http-equiv="refresh" content="30">', page)
    forbidden = (
        'fetch(', 'XMLHttpRequest', 'WebSocket', 'localStorage',
        'sessionStorage', 'indexedDB', 'document.cookie',
        'history.pushState', 'history.replaceState',
    )
    for forbidden_surface in forbidden:
        with self.subTest(forbidden_surface=forbidden_surface):
            self.assertNotIn(forbidden_surface, page)
    self.assertIn('phaseSelector.addEventListener("change"', page)
~~~

- [ ] **Step 2: Run to verify failure**

Run:

~~~bash
python3 -m unittest scripts/delivery/test_render_dashboard.py -v
~~~

Expected: FAIL because current HTML has no phase selector/data attributes and global counts.

- [ ] **Step 3: Implement renderer-scoped presentation**

Build phase_by_id, choose status["activePhaseId"], and use only its tasks for
the initial server-rendered lane cards/counts/attention/summary. Render ordered
selector, with only active option selected. Do not render every task into the
initial DOM. Show the phase label, work-type pill, and accessible status text
on server-rendered and script-created cards.

Embed only the validated status payload through `script_safe_json`:

~~~html
<script id="dashboard-data" type="application/json">…</script>
~~~

Add an inline script that reads only this payload and handles:

~~~javascript
phaseSelector.addEventListener("change", () => renderPhase(phaseSelector.value));
~~~

`renderPhase` filters payload tasks, recalculates lane counts/summary/attention,
and suppresses global active/next IDs when they are outside selected phase.
It clears and recreates selected-phase cards using `document.createElement`,
`textContent`, and renderer-defined CSS classes. It forms detail links only as
`"remediation.html#" + encodeURIComponent(task.id)`; it must never create
evidence links or any task-controlled external URL. Do not write
JSON/Markdown, fetch, persist URL state, use localStorage, or contact network.
Refresh returns to activePhaseId.

- [ ] **Step 4: Verify**

Run:

~~~bash
python3 -m unittest scripts/delivery/test_render_dashboard.py -v
~~~

Expected: PASS. Renderer --check can remain stale until Task 3 changes canonical source and regenerates HTML.

- [ ] **Step 5: Commit**

~~~bash
git add scripts/delivery/render_dashboard.py scripts/delivery/test_render_dashboard.py
git commit -m "feat: add dashboard phase filtering"
~~~

### Task 3: Canonical state, generated projection, and maintenance evidence

**Files:**
- Modify: docs/delivery/dashboard-status.json
- Modify: docs/delivery/dashboard/README.md
- Modify: docs/delivery/remediation-ledger.md
- Create: docs/delivery/task-briefs/DELIVERY-KANBAN-unified-phase-board.md
- Modify: docs/delivery/roadmap.md
- Generate: docs/delivery/dashboard/index.html
- Generate: docs/delivery/dashboard/remediation.html
- Modify: scripts/delivery/test_render_dashboard.py

**Interfaces:**
- Consumes: renderer and contract from Tasks 1–2.
- Produces: phase-complete canonical board opening on Post-MVP refinement, generated static files, and one matching operational audit entry.

- [ ] **Step 1: Write failing committed-source test**

Add:

~~~python
def test_committed_source_has_all_approved_phases_and_future_cards(self):
    status = renderer.load_and_validate(renderer.SOURCE)
    self.assertEqual(status["activePhaseId"], "post_mvp_refinement")
    self.assertEqual(
        [phase["id"] for phase in status["phases"]],
        ["remediation_r1", "post_mvp_refinement", "phase_2a",
         "phase_2b", "phase_2c", "phase_3"],
    )
    self.assertEqual(
        [
            (phase["lifecycle"], phase["dependsOnPhaseIds"])
            for phase in status["phases"]
        ],
        [
            ("historical", []),
            ("active", ["remediation_r1"]),
            ("planned", ["post_mvp_refinement"]),
            ("planned", ["phase_2a"]),
            ("planned", ["phase_2b"]),
            ("planned", ["phase_2c"]),
        ],
    )
    task_by_id = {task["id"]: task for task in status["tasks"]}
    self.assertEqual(task_by_id["RP-R10"]["phaseId"], "remediation_r1")
    for task_id in ("UX-D10", "UX-D11", "UX-D12", "DESIGN-V2",
                    "P2A-1", "P2B-1", "P2C-1", "P3-1"):
        self.assertEqual(task_by_id[task_id]["status"], "backlog")
        self.assertFalse(task_by_id[task_id]["needsUserAction"])
~~~

- [ ] **Step 2: Run to verify failure**

Run:

~~~bash
python3 -m unittest scripts/delivery/test_render_dashboard.py -v
~~~

Expected: FAIL because source does not contain phase data/future cards.

- [ ] **Step 3: Update source and docs together**

Apply the exact catalog/cards above; preserve all existing task facts and add
phaseId: remediation_r1. Future cards must have truthful planned release
conditions/transitions; no action detail/evidence is required before a real
transition. Retain the approved serial dependency graph in the catalog. Update
the roadmap so Phase 2a explicitly follows accepted Post-MVP refinement, and
Phase 3 explicitly follows Phase 2c; the roadmap, brief, and canonical gate
must agree.

Add a dated Unified delivery Kanban expansion ledger entry:

~~~markdown
**Decision:** The dashboard now displays all delivery phases in one filterable Kanban view. Remediation R1 remains accepted historical evidence; Post-MVP refinement is the active phase; future remediation cycles receive their own phases.

**Boundary:** This records planned work only. UX-D10/D11/D12, DESIGN-V2, and Phases 2a–3 remain Backlog and are not released, active, blocked, or awaiting owner action.
~~~

Create `docs/delivery/task-briefs/DELIVERY-KANBAN-unified-phase-board.md` with the decision, explicit in/out-of-scope list, ordered phase catalog, card/status table, acceptance checks, and release boundary. State verbatim that creating the Backlog cards is a dashboard-model transition, not a release or task-status transition; no UX-D10/D11/D12, DESIGN-V2, or Phase 2–3 delivery work is authorized by this brief.

Update README to say delivery dashboard, document the JSON/ledger/roadmap
authority boundary and lifecycle/dependency changes,
new-remediation-phase, and activePhaseId maintenance, and require
default/non-default phase selector verification. Keep meaningful-transition and
Blocked definitions. Change the roadmap’s refinement-queue note from “must not
change current dashboard” to visibility as Backlog under its own phase while
ledger/roadmap retain sequencing/evidence authority. Correct the roadmap's
current-release status table from remediation-in-progress/current-work to
accepted historical Remediation R1 plus the active planned Post-MVP refinement
queue, without claiming any planned card is released.

- [ ] **Step 4: Generate and verify**

Run:

~~~bash
python3 scripts/delivery/render_dashboard.py
python3 -m unittest scripts/delivery/test_render_dashboard.py -v
python3 scripts/delivery/render_dashboard.py --check
rg -n 'phase-selector|post_mvp_refinement|Remediation R1|UX-D11|Phase 2a|http-equiv="refresh" content="30"' docs/delivery/dashboard/index.html
~~~

Expected: renderer writes both pages, tests PASS, --check reports current output, and generated page contains selector, phases, future cards, and refresh marker.

Open index.html directly. Confirm initial Post-MVP phase; each selector choice changes only cards/counts/summary/attention; Remediation R1 preserves accepted cards/detail links; refresh returns to Post-MVP; no selector action writes repo files.

- [ ] **Step 5: Commit coupled state/docs/artifacts**

~~~bash
git add docs/delivery/dashboard-status.json docs/delivery/dashboard/README.md \
  docs/delivery/dashboard/index.html docs/delivery/dashboard/remediation.html \
  docs/delivery/remediation-ledger.md docs/delivery/task-briefs/DELIVERY-KANBAN-unified-phase-board.md \
  docs/delivery/roadmap.md \
  scripts/delivery/test_render_dashboard.py
git commit -m "docs: expand delivery dashboard phases"
~~~

## Independent gate and review sequence

1. **Architect:** verify file-local safety, no persistence/network surface, embedded-data encoding, and evidence-link protections.
2. **TPM:** verify ordering, Backlog dependencies, and no future work is presented as blocked/released.
3. **QA:** independently run the suite, renderer check, and local-browser default/non-default phase smoke.
4. **Delivery Manager:** reconcile cards to roadmap/ledger, record one model-expansion entry, release no future card.
5. **Code Reviewer:** review inline script for text-safe DOM rendering, phase isolation, no fetch/storage/write behavior, and refresh compatibility.

## Self-review

- **Spec coverage:** Tasks 1–2 cover phase validation, default filter, phase labels, scoped summary/attention, five lanes, file-local/no-network, and refresh. Task 3 supplies six phases, eight approved cards, R1 historical membership, generated output, and roadmap/ledger maintenance.
- **Placeholder scan:** Every task has exact paths, tests, commands, expected result, and concrete implementation boundary.
- **Type consistency:** phases, activePhaseId, phaseId, phase-selector, data-phase-id, data-task-phase, load_and_validate, render_dashboard, and render_detail_page are consistent.

## Gate risks

- No automated dashboard tests currently exist; the new suite is necessary but does not replace required local-browser smoke.
- Do not use unsanitized innerHTML in the filter script. Use textContent for task-derived text or renderer-escaped static markup.
- activeTaskId/nextEligibleTaskId are global source fields for compatibility; suppress them if outside selected phase.
- The remediation ledger remains historical evidence. Add one broader-board boundary entry; do not rewrite accepted records or silently rename the ledger.
