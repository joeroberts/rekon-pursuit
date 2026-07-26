# Rekon Pursuit delivery dashboard

`index.html` and `remediation.html` are committed, static projections of the
canonical operational state in [`../dashboard-status.json`](../dashboard-status.json).
Open `index.html` directly in a browser; it needs no server and reloads every
30 seconds. Task-detail links stay inside this directory so they work in a
sandboxed local browser.

## Update workflow

Only update the dashboard for a meaningful delivery transition:
`Backlog → Next up → In progress → Accepted`, or a genuine material blocker
appearing or resolving. Routine progress, individual checks, commits, and
documentation changes do not change this dashboard.

1. Update the relevant task in `docs/delivery/dashboard-status.json`, including
   its status, work type, release condition, latest meaningful transition,
   evidence link,
   and material user action when required.
2. Make the matching audit/evidence entry in
   `docs/delivery/remediation-ledger.md`. These two records change together.
3. Regenerate the committed static page:

   ```bash
   python3 scripts/delivery/render_dashboard.py
   ```

4. Verify it before committing:

   ```bash
   python3 scripts/delivery/render_dashboard.py --check
   open docs/delivery/dashboard/index.html
   ```

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
