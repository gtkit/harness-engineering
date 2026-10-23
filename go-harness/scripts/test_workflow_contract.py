#!/usr/bin/env python3
"""Functional regression of workflow guards; no real Go or quality gates run."""
from __future__ import annotations

import contextlib
import io
import json
import os
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / ".openspec-auto/tools"))
import hook_common as common
import workflow_state as workflow


class WorkflowCase(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="workflow contract ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "app.py").write_text("value = 1\n")
        (self.root / "test_check.py").write_text("print('functional evidence')\n")
        (self.root / "AGENTS.md").write_text("rules\nsecond line\n")
        self.contract = {
            "schema_version": 1, "stage": "2", "change": "fixture-change",
            "allowed_files": [{"path": "app.py", "kind": "code"}],
            "required_context": [{"path": "AGENTS.md", "kind": "rules", "name": "rules"}],
            "checks": [{"id": "unit", "kind": "functional", "argv": ["python3", "test_check.py"], "timeout_seconds": 3}],
            "regressions": [{"error_id": "ERR-fixture", "reproduction": "missing evidence", "checks": ["unit"]}],
        }
        self.write_plan()
        self.store = workflow.SessionStore(self.root, "session-A")
        workflow.record_request(self.store, "按计划实施第二阶段代码")
        status = patch.object(common, "openspec_status", return_value={
            "applyRequires": ["tasks"], "artifacts": [{"id": "tasks", "status": "done"}]})
        status.start()
        self.addCleanup(status.stop)

    def write_plan(self) -> None:
        (self.root / "plan.md").write_text("# Plan\n" + workflow.MARKER + "\n```json\n" + json.dumps(self.contract) + "\n```\n")

    def prepare(self) -> None:
        with contextlib.redirect_stdout(io.StringIO()):
            for name in ("plan.md", "AGENTS.md"):
                workflow.read_context(self.store, "plan.md", name, 1, 1000)
        workflow.activate(self.store, "plan.md")


class StateTests(WorkflowCase):
    def test_sessions_and_legacy_state_are_isolated(self) -> None:
        self.prepare()
        legacy = self.root / ".openspec-auto/state/current_change.json"
        legacy.write_text('{"name":"other-project"}')
        other = workflow.SessionStore(self.root, "session-B")
        workflow.record_request(other, "实施第二阶段代码")
        allowed, _ = workflow.allow_files(self.root, {"session_id": "session-B"}, ["app.py"])
        self.assertFalse(allowed)
        self.assertIsNone(other.read()["plan"])
        self.assertEqual(self.store.read()["plan"]["change"], "fixture-change")
        self.assertEqual(legacy.read_text(), '{"name":"other-project"}')

    def test_concurrent_same_session_updates_do_not_lose_revisions(self) -> None:
        with ThreadPoolExecutor(max_workers=4) as pool:
            list(pool.map(lambda _: workflow.record_request(self.store, "只解释代码"), range(16)))
        self.assertEqual(self.store.read()["revision"], 17)

    def test_separate_processes_preserve_session_revisions(self) -> None:
        program = "from pathlib import Path; import sys; from workflow_state import SessionStore, record_request; s=SessionStore(Path(sys.argv[1]),'session-A'); [record_request(s,'只解释') for _ in range(6)]"
        environment = {**os.environ, "PYTHONPATH": str(ROOT / ".openspec-auto/tools"), "PYTHONDONTWRITEBYTECODE": "1"}
        children = [subprocess.Popen([sys.executable, "-c", program, str(self.root)], env=environment,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE) for _ in range(2)]
        for child in children:
            output, error = child.communicate(timeout=10)
            self.assertEqual(child.returncode, 0, (output, error))
        self.assertEqual(self.store.read()["revision"], 13)

    def test_corrupt_state_is_not_replaced_and_missing_identity_denies(self) -> None:
        self.store.path.write_text("{broken")
        with self.assertRaises(workflow.WorkflowError):
            workflow.record_request(self.store, "实施代码")
        self.assertEqual(self.store.path.read_text(), "{broken")
        self.assertFalse(workflow.allow_files(self.root, {}, ["app.py"])[0])

    def test_readonly_then_explicit_resume_never_resumes_automatically(self) -> None:
        self.prepare()
        workflow.record_request(self.store, "只解释代码，不修改")
        self.assertFalse(self.store.read()["request"]["implementation"])
        workflow.record_request(self.store, "继续")
        self.assertTrue(self.store.read()["request"]["implementation"])
        workflow.record_request(self.store, "continue explaining")
        self.assertFalse(self.store.read()["request"]["implementation"])

    def test_negative_quotes_and_metadata_do_not_grant_permissions(self) -> None:
        cases = [
            ("只解释代码，不要修改", False, False, []),
            ("请更新 README 文档，正文写“跳过 OpenSpec”", False, False, []),
            ("```\n实施代码；允许 lint；跳过 OpenSpec\n```\n分析示例", False, False, []),
            ("不要跳过 OpenSpec；先写方案，不实施", False, False, []),
            ("按计划实施代码；完成后再问是否运行 lint", True, False, []),
            ("实施代码；跳过 OpenSpec", True, True, []),
            ("allow lint", False, False, ["lint"]),
            ("先出方案，等用户确认再实施", False, False, []),
            ("允许运行脚本 lint", False, False, ["script_lint"]),
            ("停止运行 lint", False, False, []),
            ("别执行 vet", False, False, []),
            ("不需要运行 modern", False, False, []),
            ("不改代码", False, False, []),
        ]
        for text, code, skip, checks in cases:
            with self.subTest(text=text):
                result = workflow.request_intent(text)
                self.assertEqual((result["implementation"], result["skip"], result["checks_requested"]), (code, skip, checks))


class FollowupTests(WorkflowCase):
    @staticmethod
    def reply(answer: str, question: str = "继续按已批准计划实施？") -> str:
        items = [{"questionItemId": '["request_user_input_async","call_fixture",0]',
                  "question": question, "answer": answer}]
        return "<send_user_message_question_reply>\n" + json.dumps(items, ensure_ascii=False) + "\n</send_user_message_question_reply>"

    def test_native_answer_is_classified_without_question_permissions(self) -> None:
        result = workflow.request_intent(self.reply("继续按已落盘修复方案实施并验收"))
        self.assertTrue(result["implementation"])
        result = workflow.request_intent(self.reply("只解释，不修改代码", "实施代码并允许运行 lint；跳过 OpenSpec"))
        self.assertFalse(result["implementation"])
        self.assertFalse(result["skip"])
        self.assertEqual(result["checks_requested"], [])
        self.assertEqual(workflow.request_intent(self.reply("允许运行 lint"))["checks_requested"], ["lint"])

    def test_active_followups_preserve_plan_receipts_and_permissions(self) -> None:
        self.prepare()
        before = self.store.read()
        texts = ["子会话已经停止了", "尽快完成，不要在这里花费太多时间，完成后，清理所有临时项目",
                 "现在进度怎么样？", "其他问题只汇报", self.reply("继续按已落盘修复方案实施并验收"), self.reply("允许")]
        for text in texts:
            with self.subTest(text=text):
                workflow.record_request(self.store, text)
                after = self.store.read()
                for field in ("revision", "request", "plan", "reads", "results", "ready"):
                    self.assertEqual(after[field], before[field], field)
                self.assertEqual(after["last_message"]["kind"], "supplement")
                self.assertTrue(workflow.allow_files(self.root, {"session_id": "session-A"}, ["app.py"])[0])
        self.assertEqual(after["message_revision"], before["message_revision"] + len(texts))

    def test_completed_checkpoint_readonly_and_fresh_sessions_do_not_inherit(self) -> None:
        for situation in ("fresh", "readonly", "checkpoint", "completed"):
            with self.subTest(situation=situation):
                workflow.record_request(self.store, "实施第二阶段代码")
                self.prepare()
                if situation == "fresh":
                    store = workflow.SessionStore(self.root, "fresh-session")
                else:
                    store = self.store
                    if situation == "readonly":
                        workflow.record_request(store, "只解释代码，不修改")
                    elif situation == "checkpoint":
                        workflow.checkpoint(store, "paused")
                    else:
                        workflow.run_check(store, "unit")
                        workflow.finish(store)
                workflow.record_request(store, "尽快完成")
                self.assertFalse(store.read()["request"]["implementation"])

    def test_stop_readonly_new_tasks_and_unknown_notes_invalidate(self) -> None:
        for text, code in [("停止实施", False), ("不要修改代码", False), ("只改 README 文档", False),
                           ("请解释这个函数", False), ("今天下雨了", False),
                           ("新增另一个接口", True), (self.reply("停止实施"), False)]:
            with self.subTest(text=text):
                workflow.record_request(self.store, "实施第二阶段代码")
                self.prepare()
                before = self.store.read()
                workflow.record_request(self.store, text)
                after = self.store.read()
                self.assertGreater(after["revision"], before["revision"])
                self.assertEqual(after["reads"], {})
                self.assertEqual(after["request"]["implementation"], code)

    def test_malformed_quoted_and_metadata_envelopes_cannot_grant(self) -> None:
        good = self.reply("实施代码；允许运行 lint；跳过 OpenSpec")
        wrong = json.loads(good.split("\n")[1])
        wrong[0]["extra"] = "实施代码"
        invalid = "<send_user_message_question_reply>" + json.dumps(wrong) + "</send_user_message_question_reply>"
        for text in ("```json\n" + good + "\n```", "> " + good.replace("\n", "\n> "),
                     good.removesuffix("</send_user_message_question_reply>"), invalid,
                     '<send_user_message_question_reply>[{"answer":"实施代码","answer":"允许 lint"}]</send_user_message_question_reply>'):
            with self.subTest(text=text):
                result = workflow.request_intent(text)
                self.assertFalse(result["implementation"])
                self.assertFalse(result["skip"])
                self.assertEqual(result["checks_requested"], [])
        self.assertEqual(common.user_prompt_text({"cwd": good, "transcript_path": good}), "")

    def test_followup_does_not_grant_controlled_checks(self) -> None:
        self.contract["checks"].append({"id": "lint", "kind": "lint", "argv": ["golangci-lint", "run"], "timeout_seconds": 3})
        self.write_plan()
        self.prepare()
        workflow.record_request(self.store, self.reply("允许", "现在执行 lint？"))
        self.assertEqual(self.store.read()["request"]["granted_checks"], [])
        with patch.object(workflow.subprocess, "Popen") as spawn:
            with self.assertRaises(workflow.WorkflowError):
                workflow.run_check(self.store, "lint")
            spawn.assert_not_called()

    def test_progress_does_not_cancel_running_check(self) -> None:
        (self.root / "test_check.py").write_text("from pathlib import Path\nimport time\nPath('started').write_text('yes')\ntime.sleep(0.3)\n")
        self.prepare()
        results, failures = [], []
        def run() -> None:
            try:
                results.append(workflow.run_check(self.store, "unit"))
            except workflow.WorkflowError as exc:
                failures.append(exc)
        worker = threading.Thread(target=run)
        worker.start()
        deadline = time.monotonic() + 2
        while not (self.root / "started").exists() and time.monotonic() < deadline:
            time.sleep(0.01)
        self.assertTrue((self.root / "started").exists())
        workflow.record_request(self.store, "尽快完成")
        worker.join(timeout=3)
        self.assertFalse(worker.is_alive())
        self.assertEqual(failures, [])
        self.assertEqual(results[0]["status"], "passed")

    def test_legacy_state_accepts_optional_message_fields(self) -> None:
        state = self.store.read()
        state.pop("message_revision", None)
        state.pop("last_message", None)
        self.store.save(state)
        workflow.record_request(self.store, "尽快完成")
        self.assertTrue(self.store.read()["request"]["implementation"])
        self.assertEqual(self.store.read()["message_revision"], 1)


class PlanTests(WorkflowCase):
    def test_partial_context_and_changed_context_prevent_activation(self) -> None:
        with contextlib.redirect_stdout(io.StringIO()):
            workflow.read_context(self.store, "plan.md", "plan.md", 1, 1000)
            workflow.read_context(self.store, "plan.md", "AGENTS.md", 1, 1)
        with self.assertRaisesRegex(workflow.WorkflowError, "partially"):
            workflow.activate(self.store, "plan.md")
        self.prepare()
        (self.root / "AGENTS.md").write_text("changed rule\n")
        self.assertFalse(workflow.allow_files(self.root, {"session_id": "session-A"}, ["app.py"])[0])

    def test_plan_rejects_escape_unknown_fields_and_command_kind_forgery(self) -> None:
        for mutation in ("escape", "field", "command"):
            with self.subTest(mutation=mutation):
                original = json.loads(json.dumps(self.contract))
                if mutation == "escape":
                    self.contract["allowed_files"][0]["path"] = "../outside.py"
                elif mutation == "field":
                    self.contract["approved"] = True
                else:
                    self.contract["checks"][0]["argv"] = ["go", "vet", "./..."]
                self.write_plan()
                with self.assertRaises(workflow.WorkflowError):
                    workflow.load_plan(self.root, "plan.md")
                self.contract = original

    def test_symlink_target_outside_project_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as outside:
            (self.root / "escape").symlink_to(outside, target_is_directory=True)
            self.contract["allowed_files"][0]["path"] = "escape/app.py"
            self.write_plan()
            with self.assertRaises(workflow.WorkflowError):
                workflow.load_plan(self.root, "plan.md")

    def test_paired_skill_must_match(self) -> None:
        for owner, body in ((".agents", "one"), (".claude", "two")):
            path = self.root / owner / "skills/demo/SKILL.md"
            path.parent.mkdir(parents=True)
            path.write_text("---\nname: demo\n---\n" + body)
        self.contract["required_context"].append({"path": ".agents/skills/demo/SKILL.md", "kind": "skill", "name": "demo"})
        self.write_plan()
        with self.assertRaisesRegex(workflow.WorkflowError, "paired skill"):
            workflow.load_plan(self.root, "plan.md")

    def test_declared_installed_skill_can_be_read_without_arbitrary_external_access(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            skill = home / ".agents/skills/demo/SKILL.md"
            skill.parent.mkdir(parents=True)
            skill.write_text("---\nname: demo\n---\nskill body\n")
            self.contract["required_context"].append({"path": str(skill), "kind": "skill", "name": "demo"})
            self.write_plan()
            with patch.object(workflow.Path, "home", return_value=home), contextlib.redirect_stdout(io.StringIO()):
                workflow.read_context(self.store, "plan.md", str(skill), 1, 1000)
                self.assertIn(str(skill.resolve()), self.store.read()["reads"])
                with self.assertRaises(workflow.WorkflowError):
                    workflow.read_context(self.store, "plan.md", str(home / "private.txt"), 1, 1000)

    def test_only_allowed_targets_and_current_stage_can_be_used(self) -> None:
        self.prepare()
        payload = {"session_id": "session-A"}
        self.assertTrue(workflow.allow_files(self.root, payload, ["app.py"])[0])
        self.assertFalse(workflow.allow_files(self.root, payload, ["app.py", "outside.py"])[0])
        workflow.record_request(self.store, "实施第三阶段代码")
        with contextlib.redirect_stdout(io.StringIO()):
            workflow.read_context(self.store, "plan.md", "plan.md", 1, 1000)
            workflow.read_context(self.store, "plan.md", "AGENTS.md", 1, 1000)
        with self.assertRaisesRegex(workflow.WorkflowError, "stage"):
            workflow.activate(self.store, "plan.md")


class EvidenceTests(WorkflowCase):
    def test_real_result_required_and_code_changes_invalidate_it(self) -> None:
        self.prepare()
        with self.store.lock():
            state = self.store.read()
            state["results"]["unit"] = {"status": "passed", "exit_code": 0}
            self.store.save(state)
        with self.assertRaises(workflow.WorkflowError):
            workflow.finish(self.store)

        result = workflow.run_check(self.store, "unit")
        self.assertEqual(result["exit_code"], 0)
        self.assertEqual(result["status"], "passed")
        workflow.ready(self.store)
        self.assertTrue(workflow.finish(self.store)["complete"])
        (self.root / "other-session.py").write_text("unrelated = True\n")
        self.assertTrue(workflow.finish(self.store)["complete"])
        (self.root / "app.py").write_text("value = 2\n")
        with self.assertRaises(workflow.WorkflowError):
            workflow.finish(self.store)

    def test_changed_check_source_invalidates_previous_success(self) -> None:
        self.prepare()
        workflow.run_check(self.store, "unit")
        (self.root / "test_check.py").write_text("print('changed check')\n")
        with self.assertRaises(workflow.WorkflowError):
            workflow.ready(self.store)

    def test_failed_and_timeout_results_remain_failed(self) -> None:
        self.prepare()
        (self.root / "test_check.py").write_text("raise SystemExit(7)\n")
        result = workflow.run_check(self.store, "unit")
        self.assertEqual((result["status"], result["exit_code"]), ("failed", 7))
        with self.assertRaises(workflow.WorkflowError):
            workflow.ready(self.store)
        self.contract["checks"][0]["timeout_seconds"] = 1
        self.write_plan()
        self.prepare()
        (self.root / "test_check.py").write_text("import time\ntime.sleep(3)\n")
        result = workflow.run_check(self.store, "unit")
        self.assertEqual(result["status"], "timeout")

    def test_controlled_check_is_never_started_without_later_grant(self) -> None:
        self.contract["checks"].append({"id": "lint", "kind": "lint", "argv": ["golangci-lint", "run"], "timeout_seconds": 3})
        self.write_plan()
        self.prepare()
        workflow.record_request(self.store, "实施代码；允许运行 lint")
        with patch.object(workflow.subprocess, "Popen") as spawn:
            with self.assertRaises(workflow.WorkflowError):
                workflow.run_check(self.store, "lint")
            spawn.assert_not_called()
        workflow.run_check(self.store, "unit")
        workflow.ready(self.store)
        workflow.record_request(self.store, "允许现在运行 lint")
        self.assertEqual(self.store.read()["request"]["granted_checks"], ["lint"])
        workflow.record_request(self.store, "停止检查，不要运行 lint")
        self.assertEqual(self.store.read()["request"]["granted_checks"], [])

    def test_only_later_grant_starts_safe_fake_controlled_program(self) -> None:
        fake = self.root / "go"
        fake.write_text("#!" + sys.executable + "\nfrom pathlib import Path\nPath('fake-called').write_text('yes')\n")
        fake.chmod(0o700)
        self.contract["allowed_files"].append({"path": "go", "kind": "code"})
        self.contract["checks"].append({"id": "vet", "kind": "vet", "argv": [str(fake), "vet"], "timeout_seconds": 2})
        self.write_plan()
        self.prepare()
        with self.assertRaises(workflow.WorkflowError):
            workflow.run_check(self.store, "vet")
        self.assertFalse((self.root / "fake-called").exists())
        workflow.run_check(self.store, "unit")
        workflow.ready(self.store)
        workflow.record_request(self.store, "允许运行 vet")
        self.assertEqual(workflow.run_check(self.store, "vet")["status"], "passed")
        self.assertTrue((self.root / "fake-called").is_file())
        workflow.record_request(self.store, "停止运行 vet")
        self.assertEqual(self.store.read()["request"]["granted_checks"], [])

    def test_new_request_stops_child_and_rejects_late_result(self) -> None:
        (self.root / "test_check.py").write_text("from pathlib import Path\nimport time\nPath('started').write_text('yes')\ntime.sleep(3)\n")
        self.prepare()
        failures: list[Exception] = []
        def run() -> None:
            try:
                workflow.run_check(self.store, "unit")
            except workflow.WorkflowError as exc:
                failures.append(exc)
        worker = threading.Thread(target=run)
        worker.start()
        deadline = time.monotonic() + 2
        while not (self.root / "started").exists() and time.monotonic() < deadline:
            time.sleep(0.01)
        self.assertTrue((self.root / "started").exists())
        workflow.record_request(self.store, "停止检查")
        worker.join(timeout=2)
        self.assertFalse(worker.is_alive())
        self.assertEqual(len(failures), 1)
        self.assertFalse(self.store.read()["request"]["implementation"])
        self.assertEqual(self.store.read()["results"]["unit"]["status"], "canceled")
        workflow.record_request(self.store, "按计划实施第二阶段代码")
        (self.root / "test_check.py").write_text("print('resumed')\n")
        self.assertEqual(workflow.run_check(self.store, "unit")["status"], "passed")

    def test_stop_uses_evidence_and_allows_incomplete_checkpoint(self) -> None:
        self.prepare()
        payload = {"session_id": "session-A", "last_assistant_message": "all tests passed 已完成"}
        self.assertTrue(workflow.block_stop(self.root, payload)[0])
        workflow.checkpoint(self.store, "waiting for user")
        self.assertFalse(workflow.block_stop(self.root, payload)[0])
        workflow.record_request(self.store, "只解释代码，不要修改")
        self.assertFalse(workflow.block_stop(self.root, payload)[0])

    def test_readonly_request_cannot_mark_old_work_ready_or_complete(self) -> None:
        self.prepare()
        workflow.run_check(self.store, "unit")
        workflow.record_request(self.store, "只解释方案")
        with self.assertRaises(workflow.WorkflowError):
            workflow.ready(self.store)
        with self.assertRaises(workflow.WorkflowError):
            workflow.finish(self.store)


class CommandTests(WorkflowCase):
    def test_shell_readonly_quotes_and_runner_identity(self) -> None:
        for command, expected in (("printf 'go vet ./...; lint'", True), ("go vet ./...", False),
                                  ("make check", False), ("python3 -c 'print(1)'", False),
                                  ("echo x > app.py", False), ("cat app.py", True),
                                  ("python3 .harness/scripts/workflow.py --session session-A status", True),
                                  ("python3 .harness/scripts/workflow.py --session session-B status", False)):
            with self.subTest(command=command):
                result = workflow.allow_shell(self.root, {"session_id": "session-A", "tool_input": {"command": command}})
                self.assertEqual(result[0], expected, result)


if __name__ == "__main__":
    unittest.main(verbosity=2)
