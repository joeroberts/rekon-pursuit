# Local Delivery Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local, static Rekon Pursuit delivery dashboard from one versioned operational-status source.

**Architecture:** A standard-library Python renderer validates the small JSON contract and writes a self-contained HTML projection. The browser page embeds the rendered content and a 30-second meta refresh, so `file://` works without a server or browser fetch permissions.

**Tech Stack:** Python 3 standard library, JSON, static HTML/CSS, repository-local Markdown instructions.

## Global Constraints

- Canonical operational state is `docs/delivery/dashboard-status.json`; detailed evidence remains in `docs/delivery/remediation-ledger.md`.
- The only normal status path is Backlog → Next up → In progress → Accepted; Blocked is a genuine material impediment only.
- Use exact lanes in this order: Backlog, Next up, In progress, Accepted, Blocked.
- No Node dependency, server, database, plugin, cloud service, SwiftUI source change, or CI expansion.
- Dashboard source and ledger change together only at meaningful delivery transitions; do not infer acceptance from a commit or test.

---

### Task 1: Static dashboard source, renderer, and maintenance workflow

**Files:**

- Create: `docs/delivery/dashboard-status.json`
- Create: `scripts/delivery/render_dashboard.py`
- Create: `docs/delivery/dashboard/README.md`
- Create: `docs/delivery/dashboard/index.html`
- Modify: `docs/delivery/remediation-ledger.md`
- Modify: `docs/delivery/task-briefs/RP-DASH-001-local-delivery-dashboard.md`

**Interfaces:**

- Consumes: `docs/delivery/dashboard-status.json` with `schemaVersion`, `activeTaskId`, `nextEligibleTaskId`, and `tasks`.
- Produces: `scripts/delivery/render_dashboard.py [--check]`, which validates input and writes `docs/delivery/dashboard/index.html`.
- Produces: a self-contained `index.html` with a `30`-second refresh marker, summary, required lanes, and task cards.

- [ ] **Step 1: Define the failing operational source contract**

Create the JSON source using the approved baseline: R0/R1a/R1b accepted; R2 in progress with the exact title `Corrective pass / verification required`; R3 next up; R4–R10 backlog; no blocked tasks. Include every card’s mandatory `needsUserAction` boolean, material detail for R2 verification, current release condition, latest meaningful transition, and repository-local ledger evidence links.

- [ ] **Step 2: Run the renderer before it exists**

Run: `python3 scripts/delivery/render_dashboard.py --check`

Expected: failure because the renderer has not been created.

- [ ] **Step 3: Implement the minimal deterministic renderer**

Implement `render_dashboard.py` with these boundaries:

```python
ALLOWED_STATUSES = ("backlog", "next_up", "in_progress", "accepted", "blocked")
LANES = (("backlog", "Backlog"), ("next_up", "Next up"),
         ("in_progress", "In progress"), ("accepted", "Accepted"),
         ("blocked", "Blocked"))

def load_and_validate(source: Path) -> dict: ...
def render_dashboard(status: dict) -> str: ...
def validate_local_href(value: str) -> None: ...
```

Validation rejects unknown statuses, duplicate IDs, missing mandatory action booleans, missing action detail when required, invalid active/next IDs, absolute/schemed/outside-repository evidence links, and non-empty blocked cards without a material action detail. Render the exact lane order, requested dark Rekon state colors, per-card facts, `No action needed` when false, and attention only from `needsUserAction: true`. Escape all JSON text before placing it in HTML.

- [ ] **Step 4: Add the maintenance instruction**

Document the one workflow next to the generated page: edit JSON only at a meaningful transition; make the matching detailed-ledger update; run `python3 scripts/delivery/render_dashboard.py`; open `docs/delivery/dashboard/index.html`; confirm card facts, lane/counts, attention, links, and the 30-second reload marker. State that generated HTML is committed with the JSON update.

- [ ] **Step 5: Render and run focused verification**

Run:

```bash
python3 scripts/delivery/render_dashboard.py
python3 scripts/delivery/render_dashboard.py --check
rg -n 'http-equiv="refresh" content="30"|Backlog|Next up|In progress|Accepted|Blocked|Corrective pass / verification required' docs/delivery/dashboard/index.html
```

Expected: renderer succeeds; check mode confirms generated output matches source; required refresh marker, lanes, and R2 title are present. Open the local HTML file in a browser and confirm it renders without any running service.

- [ ] **Step 6: Commit the delivery tooling slice**

```bash
git add docs/delivery/dashboard-status.json docs/delivery/dashboard/index.html \
  docs/delivery/dashboard/README.md scripts/delivery/render_dashboard.py \
  docs/delivery/remediation-ledger.md \
  docs/delivery/task-briefs/RP-DASH-001-local-delivery-dashboard.md \
  docs/superpowers/plans/2026-07-25-local-delivery-dashboard.md
git commit -m "feat: add local delivery dashboard"
```

## Self-review

- Spec coverage: Task 1 owns the authoritative JSON, synchronized ledger baseline, static local output, exact lane/status/card/summary behavior, auto refresh, validation, and maintenance workflow.
- Placeholder scan: no deferred implementation step is required; output is static and self-contained.
- Type consistency: JSON validation and rendering consume the same task fields named in the brief.
