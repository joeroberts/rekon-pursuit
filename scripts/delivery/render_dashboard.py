#!/usr/bin/env python3
"""Render the local Rekon Pursuit delivery dashboard from its JSON status file."""

from __future__ import annotations

import argparse
import html
import json
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit


ALLOWED_STATUSES = ("backlog", "next_up", "in_progress", "accepted", "blocked")
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
    task_list = data.get("tasks")
    if not isinstance(task_list, list) or not task_list:
        raise DashboardContractError("tasks must be a non-empty array.")

    ids: set[str] = set()
    for index, task in enumerate(task_list, start=1):
        if not isinstance(task, dict):
            raise DashboardContractError(f"tasks[{index}] must be an object.")
        task_id = require_string(task.get("id"), f"tasks[{index}].id")
        if task_id in ids:
            raise DashboardContractError(f"Duplicate task ID: {task_id}")
        ids.add(task_id)
        require_string(task.get("title"), f"tasks[{index}].title")
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

    active = require_string(data.get("activeTaskId"), "activeTaskId")
    next_eligible = require_string(data.get("nextEligibleTaskId"), "nextEligibleTaskId")
    if active not in ids:
        raise DashboardContractError(f"activeTaskId {active!r} does not match a task.")
    if next_eligible not in ids:
        raise DashboardContractError(
            f"nextEligibleTaskId {next_eligible!r} does not match a task."
        )
    return data


def escape(value: object) -> str:
    return html.escape(str(value), quote=True)


def render_card(task: dict, lane_label: str) -> str:
    evidence = task.get("evidence")
    evidence_markup = ""
    if evidence:
        evidence_markup = (
            '<a class="evidence" href="{href}">{label}</a>'.format(
                href=escape(evidence["href"]), label=escape(evidence["label"])
            )
        )
    action = (
        f'<p class="action required">Action needed: {escape(task["userActionDetail"])}</p>'
        if task["needsUserAction"]
        else '<p class="action">No action needed</p>'
    )
    return f"""
      <article class="task-card status-{escape(task['status'])}">
        <div class="card-heading"><span class="task-id">{escape(task['id'])}</span><span class="status-pill">{escape(lane_label)}</span></div>
        <h3>{escape(task['title'])}</h3>
        <dl>
          <div><dt>Release condition</dt><dd>{escape(task['releaseCondition'])}</dd></div>
          <div><dt>Latest transition</dt><dd>{escape(task['latestTransition'])}</dd></div>
        </dl>
        {action}
        {evidence_markup}
      </article>"""


def render_dashboard(status: dict) -> str:
    tasks = status["tasks"]
    task_by_id = {task["id"]: task for task in tasks}
    counts = {state: sum(task["status"] == state for task in tasks) for state, _ in LANES}
    attention = [task for task in tasks if task["needsUserAction"]]
    lane_markup = []
    for state, label in LANES:
        cards = [render_card(task, label) for task in tasks if task["status"] == state]
        contents = "\n".join(cards) if cards else '<p class="empty">No tasks in this lane.</p>'
        lane_markup.append(
            f'<section class="lane lane-{state}"><header><h2>{label}</h2>'
            f'<span class="lane-count">{counts[state]}</span></header>{contents}</section>'
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
    active = task_by_id[status["activeTaskId"]]
    next_eligible = task_by_id[status["nextEligibleTaskId"]]
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
    .task-card {{ background:var(--panel); border:1px solid #34425a; border-radius:9px; padding:13px; margin-top:10px; }} .card-heading {{ display:flex; align-items:center; justify-content:space-between; gap:8px; }} .task-id {{ color:var(--cyan); font-size:12px; font-weight:800; letter-spacing:.08em; }} .status-pill {{ color:var(--lane); border:1px solid currentColor; border-radius:999px; font-size:11px; padding:2px 7px; white-space:nowrap; }} .task-card h3 {{ margin:9px 0 12px; font-size:16px; line-height:1.3; }} dl {{ margin:0; }} dl div {{ margin:9px 0; }} dd {{ margin:2px 0 0; color:#d3dbea; }} .action {{ color:var(--muted); margin:14px 0 0; }} .action.required {{ color:#f0cdfc; }} .evidence {{ display:inline-block; color:var(--cyan); font-weight:600; margin-top:10px; text-decoration:none; }} .evidence:hover {{ text-decoration:underline; }} .empty {{ color:var(--muted); font-style:italic; }}
    footer {{ color:var(--muted); font-size:12px; margin-top:20px; }} @media (max-width:1000px) {{ body {{ min-width:0; }} main {{ padding:20px; }} .summary {{ grid-template-columns:repeat(2,1fr); }} }}
  </style>
</head>
<body>
  <main>
    <header><div class="eyebrow">Rekon Pursuit</div><h1>Delivery dashboard</h1><p class="subhead">Local operational view. This page refreshes every 30 seconds.</p></header>
    <section class="summary" aria-label="Delivery summary">
      <div class="summary-item"><span class="summary-label">Current active task</span><span class="summary-value">{escape(active['id'])} — {escape(active['title'])}</span></div>
      <div class="summary-item"><span class="summary-label">Next eligible task</span><span class="summary-value">{escape(next_eligible['id'])} — {escape(next_eligible['title'])}</span></div>
      <div class="summary-item"><span class="summary-label">Accepted</span><span class="summary-value">{counts['accepted']}</span></div>
      <div class="summary-item"><span class="summary-label">Backlog</span><span class="summary-value">{counts['backlog']}</span></div>
      <div class="summary-item"><span class="summary-label">Blocked</span><span class="summary-value">{counts['blocked']}</span></div>
    </section>
    <section class="attention" aria-label="Attention queue"><h2>Attention queue</h2>{attention_markup}</section>
    <section class="board" aria-label="Delivery status board">{''.join(lane_markup)}</section>
    <footer>Source: <code>docs/delivery/dashboard-status.json</code> · Generated locally · No server required</footer>
  </main>
</body>
</html>
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="validate the source and fail if the committed HTML is stale",
    )
    args = parser.parse_args()
    try:
        rendered = render_dashboard(load_and_validate(SOURCE))
        if args.check:
            if not OUTPUT.exists() or OUTPUT.read_text(encoding="utf-8") != rendered:
                raise DashboardContractError(
                    "Generated dashboard is stale. Run: python3 scripts/delivery/render_dashboard.py"
                )
            print(f"Dashboard source and generated HTML are current: {OUTPUT.relative_to(REPO_ROOT)}")
        else:
            OUTPUT.parent.mkdir(parents=True, exist_ok=True)
            OUTPUT.write_text(rendered, encoding="utf-8")
            print(f"Rendered dashboard: {OUTPUT.relative_to(REPO_ROOT)}")
    except DashboardContractError as error:
        print(f"Dashboard error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
