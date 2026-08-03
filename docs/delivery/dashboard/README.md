# Rekon Pursuit delivery dashboard

`index.html` and `remediation.html` are committed, static projections of the
canonical operational state in [`../dashboard-status.json`](../dashboard-status.json).
Open `index.html` directly in a browser; it needs no server and reloads every
30 seconds. Task-detail links stay inside this directory so they work in a
sandboxed local browser.

The JSON is the canonical machine-readable delivery-dashboard projection. The
[remediation ledger](../remediation-ledger.md) remains the detailed accepted
Remediation R1 audit/evidence authority, and the
[roadmap](../roadmap.md) remains the product sequencing authority. Keep all
three records aligned; the dashboard does not itself release work.

## Update workflow

Only update the dashboard for a meaningful delivery transition:
`Backlog → Next up → In progress → Accepted`, or a genuine material blocker
appearing or resolving. Routine progress, individual checks, commits, and
documentation changes do not change this dashboard.

1. Update the relevant task in `docs/delivery/dashboard-status.json`, including
   its phase, status, work type, release condition, latest meaningful
   transition, evidence link, and material user action when required. When a
   phase is completed, add a distinct future remediation phase rather than
   adding work to historical Remediation R1; maintain one `activePhaseId` that
   matches the sole active lifecycle phase and retain its accepted dependencies.
2. Make the matching audit/evidence entry in
   `docs/delivery/remediation-ledger.md` and preserve roadmap sequencing in
   `docs/delivery/roadmap.md`. These records change together when a meaningful
   transition changes delivery state.
3. Regenerate the committed static page:

   ```bash
   python3 scripts/delivery/render_dashboard.py
   ```

4. Verify it before committing:

   ```bash
   python3 scripts/delivery/render_dashboard.py --check
   open docs/delivery/dashboard/index.html
   ```

   Confirm the initial `activePhaseId` selection and at least one non-default
   phase selection. Each choice must change only the visible cards, counts,
   summary, and attention queue; refresh must return to the active phase.
   Confirm the lane and count, active/next task, card facts, attention queue,
   local evidence link, and 30-second reload marker match the JSON.

`Blocked` is only for a material decision, missing authority, external
dependency, or failed prerequisite that requires intervention. Use `Backlog`
for ordinary sequencing. Every task needs an explicit `needsUserAction` boolean;
the attention queue is empty unless a task has a material action detail.
Set `activeTaskId` to `null` while no task is in progress; the dashboard then
shows “No task in progress” while `nextEligibleTaskId` identifies the planned
next task. Set `nextEligibleTaskId` to `null` while the active task has no
dependency-safe successor; the dashboard then shows “No successor eligible.”

The renderer uses only Python's standard library. It embeds state into the
HTML so the page works over `file://`; it does not fetch JSON from the browser.
Phase lifecycle is `historical`, `active`, or `planned`: historical cards are
Accepted, planned cards are Backlog with no owner action, and the active phase
may depend only on accepted historical phases. The phase selector is view state
only: it never writes JSON, ledger, roadmap, task state, or browser storage.

## Card ordering

Every phase uses the same stable, dependency-aware card order. Add an optional
`dependsOnTaskIds` array to a task when its prerequisite is another task in the
same phase. The renderer validates those references, rejects cycles, and shows
each prerequisite before its successors in the dashboard and detail page. Cards
without recorded task dependencies retain their canonical JSON/roadmap order.
This supports the existing delivery history and future product work alike; it
is not specific to any one remediation or program.
