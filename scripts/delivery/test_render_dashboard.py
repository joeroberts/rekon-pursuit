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


class DashboardContractTests(unittest.TestCase):
    def validate(self, value):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "status.json"
            source.write_text(json.dumps(value), encoding="utf-8")
            return renderer.load_and_validate(source)

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

    def test_detail_page_includes_phase_label_heading_and_compatible_fragment(self):
        status = valid_status()
        dashboard = renderer.render_dashboard(status)
        detail_page = renderer.render_detail_page(status)

        self.assertIn("Post-MVP refinement", detail_page)
        self.assertIn("<h1>Delivery task details</h1>", detail_page)
        self.assertIn('href="remediation.html#UX-D11"', dashboard)
        self.assertIn('id="UX-D11"', detail_page)
