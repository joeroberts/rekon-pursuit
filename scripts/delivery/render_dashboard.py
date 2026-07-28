#!/usr/bin/env python3
"""Render the local Rekon Pursuit delivery dashboard from its JSON status file."""

from __future__ import annotations

import argparse
import html
import json
import sys
from pathlib import Path
from urllib.parse import quote, unquote, urlsplit


ALLOWED_STATUSES = ("backlog", "next_up", "in_progress", "accepted", "blocked")
ALLOWED_PHASE_LIFECYCLES = ("historical", "active", "planned")
LANES = (
    ("backlog", "Backlog"),
    ("next_up", "Next up"),
    ("in_progress", "In progress"),
    ("accepted", "Accepted"),
    ("blocked", "Blocked"),
)
REPO_ROOT = Path(__file__).resolve().parents[2]
SOURCE = REPO_ROOT / "docs/delivery/dashboard-status.json"
OUTPUT = REPO_ROOT / "docs/delivery/dashboard/index.html"
DETAIL_OUTPUT = OUTPUT.parent / "remediation.html"


class DashboardContractError(ValueError):
    """Raised when the operational dashboard source is unsafe or incomplete."""


def require_string(value: object, description: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise DashboardContractError(f"{description} must be a non-empty string.")
    return value


def validate_local_href(value: str) -> None:
    """Require a local, repository-contained link from the generated page."""
    if any(ord(character) < 32 or ord(character) == 127 for character in value):
        raise DashboardContractError(
            f"Evidence link {value!r} must not include control characters."
        )
    parsed = urlsplit(value)
    if parsed.scheme or parsed.netloc or value.startswith("/") or "\\" in value:
        raise DashboardContractError(
            f"Evidence link {value!r} must be a repository-local relative path."
        )
    if parsed.query or parsed.fragment:
        raise DashboardContractError(
            f"Evidence link {value!r} must not include a query or fragment."
        )

    decoded_path = parsed.path
    for _ in range(16):
        if "%2f" in decoded_path.lower() or "%5c" in decoded_path.lower():
            raise DashboardContractError(
                f"Evidence link {value!r} must not encode path separators."
            )
        next_path = unquote(decoded_path)
        if next_path == decoded_path:
            break
        decoded_path = next_path
    else:
        raise DashboardContractError(
            f"Evidence link {value!r} contains too many nested URL encodings."
        )

    if any(ord(character) < 32 or ord(character) == 127 for character in decoded_path):
        raise DashboardContractError(
            f"Evidence link {value!r} must not encode control characters."
        )
    if "\\" in decoded_path:
        raise DashboardContractError(
            f"Evidence link {value!r} must be a repository-local relative path."
        )

    destination = (OUTPUT.parent / decoded_path).resolve()
    try:
        destination.relative_to(REPO_ROOT)
    except ValueError as error:
        raise DashboardContractError(
            f"Evidence link {value!r} resolves outside the repository."
        ) from error


def load_and_validate(source: Path) -> dict:
    try:
        data = json.loads(source.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise DashboardContractError(f"Dashboard source is missing: {source}") from error
    except json.JSONDecodeError as error:
        raise DashboardContractError(
            f"Dashboard source is invalid JSON at line {error.lineno}, column {error.colno}: {error.msg}"
        ) from error

    if not isinstance(data, dict):
        raise DashboardContractError("Dashboard source must contain one JSON object.")
    if data.get("schemaVersion") != 1:
        raise DashboardContractError("schemaVersion must be 1.")
    phase_list = data.get("phases")
    if not isinstance(phase_list, list) or not phase_list:
        raise DashboardContractError("phases must be a non-empty array.")

    phases: dict[str, dict] = {}
    for index, phase in enumerate(phase_list, start=1):
        if not isinstance(phase, dict):
            raise DashboardContractError(f"phases[{index}] must be an object.")
        phase_id = require_string(phase.get("id"), f"phases[{index}].id")
        if phase_id in phases:
            raise DashboardContractError(f"Duplicate phase ID: {phase_id}")
        require_string(phase.get("label"), f"phases[{index}].label")
        lifecycle = phase.get("lifecycle")
        if lifecycle not in ALLOWED_PHASE_LIFECYCLES:
            raise DashboardContractError(
                f"phases[{index}].lifecycle must be one of "
                f"{', '.join(ALLOWED_PHASE_LIFECYCLES)}."
            )
        dependencies = phase.get("dependsOnPhaseIds")
        if not isinstance(dependencies, list):
            raise DashboardContractError(f"phases[{index}].dependsOnPhaseIds must be an array.")
        phases[phase_id] = phase

    for phase_id, phase in phases.items():
        seen_dependencies: set[str] = set()
        for dependency_index, dependency_id in enumerate(phase["dependsOnPhaseIds"], start=1):
            dependency_id = require_string(
                dependency_id,
                f"phase {phase_id!r} dependsOnPhaseIds[{dependency_index}]",
            )
            if dependency_id in seen_dependencies:
                raise DashboardContractError(
                    f"Phase {phase_id!r} has duplicate dependency {dependency_id!r}."
                )
            seen_dependencies.add(dependency_id)
            if dependency_id == phase_id:
                raise DashboardContractError(f"Phase {phase_id!r} cannot depend on itself.")
            if dependency_id not in phases:
                raise DashboardContractError(
                    f"Phase {phase_id!r} depends on unknown phase {dependency_id!r}."
                )

    def visit_phase(phase_id: str, visiting: set[str], visited: set[str]) -> None:
        if phase_id in visiting:
            raise DashboardContractError("Phase dependencies must not contain a cycle.")
        if phase_id in visited:
            return
        visiting.add(phase_id)
        for dependency_id in phases[phase_id]["dependsOnPhaseIds"]:
            visit_phase(dependency_id, visiting, visited)
        visiting.remove(phase_id)
        visited.add(phase_id)

    visited_phases: set[str] = set()
    for phase_id in phases:
        visit_phase(phase_id, set(), visited_phases)

    active_phases = [phase_id for phase_id, phase in phases.items() if phase["lifecycle"] == "active"]
    if len(active_phases) != 1:
        raise DashboardContractError("phases must contain exactly one active lifecycle phase.")
    active_phase_id = require_string(data.get("activePhaseId"), "activePhaseId")
    if active_phase_id not in phases:
        raise DashboardContractError(f"activePhaseId {active_phase_id!r} does not match a phase.")
    if active_phases[0] != active_phase_id:
        raise DashboardContractError("activePhaseId must match the active lifecycle phase.")

    task_list = data.get("tasks")
    if not isinstance(task_list, list) or not task_list:
        raise DashboardContractError("tasks must be a non-empty array.")

    ids: set[str] = set()
    tasks_by_phase: dict[str, list[dict]] = {phase_id: [] for phase_id in phases}
    tasks_by_id: dict[str, dict] = {}
    for index, task in enumerate(task_list, start=1):
        if not isinstance(task, dict):
            raise DashboardContractError(f"tasks[{index}] must be an object.")
        task_id = require_string(task.get("id"), f"tasks[{index}].id")
        if task_id in ids:
            raise DashboardContractError(f"Duplicate task ID: {task_id}")
        ids.add(task_id)
        tasks_by_id[task_id] = task
        phase_id = require_string(task.get("phaseId"), f"tasks[{index}].phaseId")
        if phase_id not in phases:
            raise DashboardContractError(
                f"tasks[{index}].phaseId {phase_id!r} does not match a phase."
            )
        tasks_by_phase[phase_id].append(task)
        require_string(task.get("title"), f"tasks[{index}].title")
        require_string(task.get("workType"), f"tasks[{index}].workType")
        status = task.get("status")
        if status not in ALLOWED_STATUSES:
            raise DashboardContractError(
                f"tasks[{index}].status must be one of {', '.join(ALLOWED_STATUSES)}."
            )
        require_string(task.get("releaseCondition"), f"tasks[{index}].releaseCondition")
        require_string(task.get("latestTransition"), f"tasks[{index}].latestTransition")
        if not isinstance(task.get("needsUserAction"), bool):
            raise DashboardContractError(f"tasks[{index}].needsUserAction must be true or false.")
        action_detail = task.get("userActionDetail")
        if task["needsUserAction"]:
            require_string(action_detail, f"tasks[{index}].userActionDetail")
        elif action_detail is not None:
            raise DashboardContractError(
                f"tasks[{index}].userActionDetail is only allowed when user action is required."
            )
        if status == "blocked" and not task["needsUserAction"]:
            raise DashboardContractError(
                f"Blocked task {task_id} must include a material action detail."
            )
        evidence = task.get("evidence")
        if evidence is not None:
            if not isinstance(evidence, dict):
                raise DashboardContractError(f"tasks[{index}].evidence must be an object.")
            require_string(evidence.get("label"), f"tasks[{index}].evidence.label")
            href = require_string(evidence.get("href"), f"tasks[{index}].evidence.href")
            validate_local_href(href)

    active = data.get("activeTaskId")
    if active is not None:
        active = require_string(active, "activeTaskId")
    next_eligible = data.get("nextEligibleTaskId")
    if next_eligible is not None:
        next_eligible = require_string(next_eligible, "nextEligibleTaskId")
    if active is not None and active not in ids:
        raise DashboardContractError(f"activeTaskId {active!r} does not match a task.")
    if next_eligible is not None and next_eligible not in ids:
        raise DashboardContractError(
            f"nextEligibleTaskId {next_eligible!r} does not match a task."
        )
    for phase_id, phase in phases.items():
        tasks_in_phase = tasks_by_phase[phase_id]
        lifecycle = phase["lifecycle"]
        if lifecycle == "historical" and any(task["status"] != "accepted" for task in tasks_in_phase):
            raise DashboardContractError(f"Historical phase {phase_id!r} must contain only Accepted cards.")
        if lifecycle == "planned":
            if any(task["status"] != "backlog" for task in tasks_in_phase):
                raise DashboardContractError(f"planned phase {phase_id!r} must contain only Backlog cards.")
            if any(task["needsUserAction"] for task in tasks_in_phase):
                raise DashboardContractError(f"planned phase {phase_id!r} cannot require user action.")

    if active is not None:
        active_task = tasks_by_id[active]
        if active_task["phaseId"] != active_phase_id or active_task["status"] != "in_progress":
            raise DashboardContractError(
                "activeTaskId must identify an in-progress task in the active phase."
            )
    if next_eligible is not None:
        next_task = tasks_by_id[next_eligible]
        if next_task["phaseId"] != active_phase_id or next_task["status"] != "next_up":
            raise DashboardContractError(
                "nextEligibleTaskId must identify a next-up task in the active phase."
            )

    for dependency_id in phases[active_phase_id]["dependsOnPhaseIds"]:
        dependency = phases[dependency_id]
        if dependency["lifecycle"] != "historical":
            raise DashboardContractError(
                f"Active phase dependency {dependency_id!r} must be historical."
            )
        if any(task["status"] != "accepted" for task in tasks_by_phase[dependency_id]):
            raise DashboardContractError(
                f"Active phase dependency {dependency_id!r} must contain only Accepted cards."
            )
    return data


def escape(value: object) -> str:
    return html.escape(str(value), quote=True)


def script_safe_json(value: object) -> str:
    """Encode JSON safely for an application/json script element."""
    return (
        json.dumps(value)
        .replace("&", r"\u0026")
        .replace("<", r"\u003c")
        .replace(">", r"\u003e")
        .replace("\u2028", r"\u2028")
        .replace("\u2029", r"\u2029")
    )


def detail_href(task: dict) -> str:
    return f"remediation.html#{escape(quote(task['id'], safe=''))}"


def status_label(status: str) -> str:
    return status.replace("_", " ").title()


def render_card(task: dict, phase_label: str) -> str:
    action = (
        f'<p class="action required">Action needed: {escape(task["userActionDetail"])}</p>'
        if task["needsUserAction"]
        else '<p class="action">No action needed</p>'
    )
    return f"""
      <article class="task-card status-{escape(task['status'])}">
        <div class="card-heading"><span class="task-id">{escape(task['id'])}</span><span class="work-type">{escape(task['workType'])}</span></div>
        <div class="card-meta"><span class="phase-label">{escape(phase_label)}</span><span class="status-text">Status: {escape(status_label(task['status']))}</span></div>
        <h3>{escape(task['title'])}</h3>
        <dl>
          <div><dt>Release condition</dt><dd>{escape(task['releaseCondition'])}</dd></div>
          <div><dt>Latest transition</dt><dd>{escape(task['latestTransition'])}</dd></div>
        </dl>
        {action}
        <a class="details-link" href="{detail_href(task)}">View task details</a>
      </article>"""


def render_dashboard(status: dict) -> str:
    phase_by_id = {phase["id"]: phase for phase in status["phases"]}
    active_phase_id = status["activePhaseId"]
    active_phase = phase_by_id[active_phase_id]
    tasks = [task for task in status["tasks"] if task["phaseId"] == active_phase_id]
    task_by_id = {task["id"]: task for task in tasks}
    counts = {state: sum(task["status"] == state for task in tasks) for state, _ in LANES}
    attention = [task for task in tasks if task["needsUserAction"]]
    lane_markup = []
    for state, label in LANES:
        cards = [render_card(task, active_phase["label"]) for task in tasks if task["status"] == state]
        contents = "\n".join(cards) if cards else '<p class="empty">No tasks in this lane.</p>'
        lane_markup.append(
            f'<section class="lane lane-{state}"><header><h2>{label}</h2>'
            f'<span class="lane-count" data-lane-count="{state}">{counts[state]}</span></header>'
            f'<div data-lane-content="{state}">{contents}</div></section>'
        )
    attention_markup = (
        "<ul>"
        + "".join(
            f'<li><strong>{escape(task["id"])}:</strong> '
            f'{escape(task["userActionDetail"])}</li>'
            for task in attention
        )
        + "</ul>"
        if attention
        else '<p class="attention-empty">Nothing needs your attention.</p>'
    )
    active_id = status.get("activeTaskId")
    active = task_by_id.get(active_id) if active_id else None
    next_eligible_id = status.get("nextEligibleTaskId")
    next_eligible = task_by_id.get(next_eligible_id) if next_eligible_id else None
    phase_options = "".join(
        f'<option value="{escape(phase["id"])}"'
        f'{" selected" if phase["id"] == active_phase_id else ""}>'
        f'{escape(phase["label"])} ({escape(phase["lifecycle"].title())})</option>'
        for phase in status["phases"]
    )
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="refresh" content="30">
  <title>Rekon Pursuit — Delivery dashboard</title>
  <style>
    :root {{ color-scheme: dark; --ink:#f3f6fb; --muted:#a6b2c7; --surface:#0d1423; --panel:#151f32; --line:#2b3850; --cyan:#20c9ef; --violet:#9a6cff; --amber:#e4a843; --emerald:#5cae85; --coral:#e6746b; }}
    * {{ box-sizing:border-box; }} body {{ margin:0; min-width:960px; background:radial-gradient(circle at top right,#172b4d 0,#0a0f1a 44rem); color:var(--ink); font:15px/1.45 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; }}
    main {{ max-width:1780px; margin:0 auto; padding:32px; }} .eyebrow {{ color:var(--cyan); font-size:12px; font-weight:700; letter-spacing:.16em; text-transform:uppercase; }} h1 {{ margin:6px 0 8px; font-size:30px; }} .subhead {{ color:var(--muted); margin:0; }}
    .summary {{ display:grid; grid-template-columns:1.35fr 1.35fr repeat(3,.55fr); gap:12px; margin:24px 0 18px; }} .summary-item,.attention {{ background:rgba(21,31,50,.93); border:1px solid var(--line); border-radius:12px; padding:14px; }} .summary-label,dt {{ color:var(--muted); font-size:11px; font-weight:700; letter-spacing:.1em; text-transform:uppercase; }} .summary-value {{ display:block; margin-top:3px; font-weight:700; }}
    .attention {{ margin-bottom:18px; border-left:3px solid var(--violet); }} .attention h2 {{ margin:0 0 8px; font-size:16px; }} .attention ul {{ margin:0; padding-left:20px; }} .attention-empty {{ margin:0; color:var(--muted); }}
    .board {{ display:grid; grid-template-columns:repeat(5,minmax(260px,1fr)); gap:14px; align-items:start; overflow-x:auto; padding-bottom:14px; }} .lane {{ min-height:280px; background:rgba(13,20,35,.82); border:1px solid var(--line); border-top:4px solid var(--lane); border-radius:12px; padding:13px; }} .lane-backlog {{ --lane:var(--amber); }} .lane-next_up {{ --lane:var(--violet); }} .lane-in_progress {{ --lane:var(--cyan); }} .lane-accepted {{ --lane:var(--emerald); }} .lane-blocked {{ --lane:var(--coral); }} .lane header {{ display:flex; justify-content:space-between; align-items:center; margin-bottom:12px; }} .lane h2 {{ font-size:17px; margin:0; }} .lane-count {{ color:var(--lane); font-weight:700; }}
    .phase-control {{ display:flex; align-items:center; gap:10px; margin:20px 0 0; }} .phase-control label {{ color:var(--muted); font-size:12px; font-weight:700; letter-spacing:.08em; text-transform:uppercase; }} .phase-control select {{ min-width:260px; border:1px solid var(--line); border-radius:8px; background:var(--panel); color:var(--ink); padding:8px; font:inherit; }} .selected-phase {{ color:var(--cyan); font-weight:700; }}
    .task-card {{ background:var(--panel); border:1px solid #34425a; border-radius:9px; padding:13px; margin-top:10px; }} .card-heading,.card-meta {{ display:flex; align-items:center; justify-content:space-between; gap:8px; }} .task-id {{ color:var(--cyan); font-size:12px; font-weight:800; letter-spacing:.08em; }} .work-type {{ color:#c9d5ed; background:#25324a; border-radius:999px; font-size:11px; font-weight:700; padding:2px 7px; white-space:nowrap; }} .card-meta {{ color:var(--muted); font-size:11px; margin-top:8px; }} .status-text {{ font-weight:700; }} .task-card h3 {{ margin:9px 0 12px; font-size:16px; line-height:1.3; }} dl {{ margin:0; }} dl div {{ margin:9px 0; }} dd {{ margin:2px 0 0; color:#d3dbea; }} .action {{ color:var(--muted); margin:14px 0 0; }} .action.required {{ color:#f0cdfc; }} .details-link {{ display:inline-block; color:var(--cyan); font-weight:600; margin-top:10px; text-decoration:none; }} .details-link:hover {{ text-decoration:underline; }} .empty {{ color:var(--muted); font-style:italic; }}
    footer {{ color:var(--muted); font-size:12px; margin-top:20px; }} @media (max-width:1000px) {{ body {{ min-width:0; }} main {{ padding:20px; }} .summary {{ grid-template-columns:repeat(2,1fr); }} }}
  </style>
</head>
<body>
  <main>
    <header><div class="eyebrow">Rekon Pursuit</div><h1>Delivery dashboard</h1><p class="subhead">Local operational view. This page refreshes every 30 seconds.</p><div class="phase-control"><label for="phase-selector">Delivery phase</label><select id="phase-selector" data-active-phase="{escape(active_phase_id)}">{phase_options}</select><span class="selected-phase" id="selected-phase-label">{escape(active_phase['label'])}</span></div></header>
    <section class="summary" aria-label="Delivery summary">
      <div class="summary-item"><span class="summary-label">Current active task</span><span class="summary-value" id="summary-active">{escape(active['id']) + ' — ' + escape(active['title']) if active else 'No task in progress'}</span></div>
      <div class="summary-item"><span class="summary-label">Next eligible task</span><span class="summary-value" id="summary-next">{escape(next_eligible['id']) + ' — ' + escape(next_eligible['title']) if next_eligible else 'No successor eligible'}</span></div>
      <div class="summary-item"><span class="summary-label">Accepted</span><span class="summary-value" id="summary-accepted">{counts['accepted']}</span></div>
      <div class="summary-item"><span class="summary-label">Backlog</span><span class="summary-value" id="summary-backlog">{counts['backlog']}</span></div>
      <div class="summary-item"><span class="summary-label">Blocked</span><span class="summary-value" id="summary-blocked">{counts['blocked']}</span></div>
    </section>
    <section class="attention" aria-label="Attention queue"><h2>Attention queue</h2><div id="attention-queue">{attention_markup}</div></section>
    <section class="board" aria-label="Delivery status board">{''.join(lane_markup)}</section>
    <footer>Source: <code>docs/delivery/dashboard-status.json</code> · Generated locally · No server required</footer>
  </main>
  <script id="dashboard-data" type="application/json">{script_safe_json(status)}</script>
  <script>
    (() => {{
      const dashboardData = JSON.parse(document.getElementById("dashboard-data").textContent);
      const phaseSelector = document.getElementById("phase-selector");
      const phaseById = new Map(dashboardData.phases.map((phase) => [phase.id, phase]));
      const laneStates = {json.dumps([state for state, _ in LANES])};

      function taskSummary(task) {{
        return task ? task.id + " — " + task.title : null;
      }}

      function appendDefinition(list, term, description) {{
        const row = document.createElement("div");
        const dt = document.createElement("dt");
        const dd = document.createElement("dd");
        dt.textContent = term;
        dd.textContent = description;
        row.append(dt, dd);
        list.append(row);
      }}

      function renderCard(task, phase) {{
        const card = document.createElement("article");
        card.className = "task-card status-" + task.status;
        const heading = document.createElement("div");
        heading.className = "card-heading";
        const taskId = document.createElement("span");
        taskId.className = "task-id";
        taskId.textContent = task.id;
        const workType = document.createElement("span");
        workType.className = "work-type";
        workType.textContent = task.workType;
        heading.append(taskId, workType);
        const meta = document.createElement("div");
        meta.className = "card-meta";
        const phaseLabel = document.createElement("span");
        phaseLabel.className = "phase-label";
        phaseLabel.textContent = phase.label;
        const status = document.createElement("span");
        status.className = "status-text";
        status.textContent = "Status: " + task.status.replaceAll("_", " ").replace(/\\b\\w/g, (letter) => letter.toUpperCase());
        meta.append(phaseLabel, status);
        const title = document.createElement("h3");
        title.textContent = task.title;
        const details = document.createElement("dl");
        appendDefinition(details, "Release condition", task.releaseCondition);
        appendDefinition(details, "Latest transition", task.latestTransition);
        const action = document.createElement("p");
        action.className = task.needsUserAction ? "action required" : "action";
        action.textContent = task.needsUserAction ? "Action needed: " + task.userActionDetail : "No action needed";
        const detailsLink = document.createElement("a");
        detailsLink.className = "details-link";
        detailsLink.href = "remediation.html#" + encodeURIComponent(task.id);
        detailsLink.textContent = "View task details";
        card.append(heading, meta, title, details, action, detailsLink);
        return card;
      }}

      function renderPhase(phaseId) {{
        const phase = phaseById.get(phaseId);
        if (!phase) return;
        const tasks = dashboardData.tasks.filter((task) => task.phaseId === phaseId);
        const counts = Object.fromEntries(laneStates.map((state) => [state, 0]));
        tasks.forEach((task) => {{ counts[task.status] += 1; }});
        document.getElementById("selected-phase-label").textContent = phase.label;
        laneStates.forEach((state) => {{
          document.querySelector('[data-lane-count="' + state + '"]').textContent = counts[state];
          const content = document.querySelector('[data-lane-content="' + state + '"]');
          content.replaceChildren();
          const cards = tasks.filter((task) => task.status === state);
          if (cards.length) cards.forEach((task) => content.append(renderCard(task, phase)));
          else {{
            const empty = document.createElement("p");
            empty.className = "empty";
            empty.textContent = "No tasks in this lane.";
            content.append(empty);
          }}
        }});
        const activeTask = dashboardData.tasks.find((task) => task.id === dashboardData.activeTaskId && task.phaseId === phaseId);
        const nextTask = dashboardData.tasks.find((task) => task.id === dashboardData.nextEligibleTaskId && task.phaseId === phaseId);
        document.getElementById("summary-active").textContent = taskSummary(activeTask) || "No task in progress";
        document.getElementById("summary-next").textContent = taskSummary(nextTask) || "No successor eligible";
        ["accepted", "backlog", "blocked"].forEach((state) => {{
          document.getElementById("summary-" + state).textContent = counts[state];
        }});
        const attention = document.getElementById("attention-queue");
        attention.replaceChildren();
        const attentionTasks = tasks.filter((task) => task.needsUserAction);
        if (attentionTasks.length) {{
          const list = document.createElement("ul");
          attentionTasks.forEach((task) => {{
            const item = document.createElement("li");
            const taskId = document.createElement("strong");
            taskId.textContent = task.id + ": ";
            item.append(taskId, document.createTextNode(task.userActionDetail));
            list.append(item);
          }});
          attention.append(list);
        }} else {{
          const empty = document.createElement("p");
          empty.className = "attention-empty";
          empty.textContent = "Nothing needs your attention.";
          attention.append(empty);
        }}
      }}

      phaseSelector.addEventListener("change", () => renderPhase(phaseSelector.value));
    }})();
  </script>
</body>
</html>
"""


def render_detail_page(status: dict) -> str:
    phase_labels = {phase["id"]: phase["label"] for phase in status["phases"]}
    sections = []
    for task in status["tasks"]:
        evidence = task.get("evidence", {})
        evidence_label = evidence.get("label", "No separate evidence source recorded")
        action = task.get("userActionDetail", "No action needed")
        sections.append(
            f'''<article id="{escape(task['id'])}" class="detail status-{escape(task['status'])}">
  <div class="heading"><span class="task-id">{escape(task['id'])}</span><span>{escape(phase_labels[task['phaseId']])}</span><span>{escape(task['workType'])}</span><span>{escape(task['status'].replace('_', ' ').title())}</span></div>
  <h2>{escape(task['title'])}</h2>
  <dl><div><dt>Release condition</dt><dd>{escape(task['releaseCondition'])}</dd></div>
  <div><dt>Latest transition</dt><dd>{escape(task['latestTransition'])}</dd></div>
  <div><dt>User action</dt><dd>{escape(action)}</dd></div>
  <div><dt>Evidence record</dt><dd>{escape(evidence_label)}</dd></div></dl>
</article>'''
        )
    return f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta http-equiv="refresh" content="30"><title>Rekon Pursuit — Remediation details</title>
<style>:root{{color-scheme:dark;--ink:#f3f6fb;--muted:#a6b2c7;--surface:#0d1423;--panel:#151f32;--line:#2b3850;--cyan:#20c9ef}}*{{box-sizing:border-box}}body{{margin:0;background:#0a0f1a;color:var(--ink);font:15px/1.45 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}}main{{max-width:960px;margin:0 auto;padding:32px}}a{{color:var(--cyan)}}h1{{margin:10px 0 6px}}.subhead,dd{{color:var(--muted)}}.detail{{scroll-margin-top:24px;background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:18px;margin:16px 0}}.heading{{display:flex;gap:8px;align-items:center;color:#c9d5ed;font-size:12px;font-weight:700;text-transform:uppercase;letter-spacing:.08em}}.task-id{{color:var(--cyan)}}h2{{margin:9px 0 14px;font-size:20px}}dl{{margin:0}}dl div{{margin:12px 0}}dt{{color:var(--muted);font-size:11px;font-weight:700;letter-spacing:.1em;text-transform:uppercase}}dd{{margin:3px 0 0}}</style></head>
<body><main><a href="index.html">← Back to dashboard</a><h1>Delivery task details</h1><p class="subhead">A local dashboard detail view. Refreshes every 30 seconds.</p>{''.join(sections)}</main></body></html>'''


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="validate the source and fail if the committed HTML is stale",
    )
    args = parser.parse_args()
    try:
        status = load_and_validate(SOURCE)
        rendered = render_dashboard(status)
        detail_rendered = render_detail_page(status)
        if args.check:
            if (
                not OUTPUT.exists()
                or OUTPUT.read_text(encoding="utf-8") != rendered
                or not DETAIL_OUTPUT.exists()
                or DETAIL_OUTPUT.read_text(encoding="utf-8") != detail_rendered
            ):
                raise DashboardContractError(
                    "Generated dashboard is stale. Run: python3 scripts/delivery/render_dashboard.py"
                )
            print(f"Dashboard source and generated HTML are current: {OUTPUT.relative_to(REPO_ROOT)}")
        else:
            OUTPUT.parent.mkdir(parents=True, exist_ok=True)
            OUTPUT.write_text(rendered, encoding="utf-8")
            DETAIL_OUTPUT.write_text(detail_rendered, encoding="utf-8")
            print(f"Rendered dashboard: {OUTPUT.relative_to(REPO_ROOT)}")
    except DashboardContractError as error:
        print(f"Dashboard error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
