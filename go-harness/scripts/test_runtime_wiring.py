#!/usr/bin/env python3
"""Phase-one functional tests; never run payload commands or project Go gates."""
from __future__ import annotations

import contextlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / ".openspec-auto/tools"
sys.path.insert(0, str(TOOLS))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import hook_common as common
import workflow_state as workflow
from fixture_diagnostics import SubprocessTrace, record_process, retain_failure


def executable(path: Path, body: str) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f"#!{sys.executable}\n" + body, encoding="utf-8")
    path.chmod(0o700)
    return path


def invoke(args: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, text=True, capture_output=True, timeout=20, check=False, **kwargs)


class IsolatedCase(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="harness wiring ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)


class RuleAndReaderTests(IsolatedCase):
    def test_rule_checker_detects_drift_and_does_not_write(self) -> None:
        checker = ROOT / ".harness/scripts/check-agent-rules.py"
        for name in ("AGENTS.md", "CLAUDE.md"):
            (self.root / name).write_text(f"# {name}\n\n## 行为纪律（铁律）\n\nrule\n")
        result = invoke([sys.executable, str(checker), str(self.root)])
        self.assertEqual(result.returncode, 0, result.stderr)
        path = self.root / "CLAUDE.md"
        path.write_text(path.read_text() + "drift\n")
        before = path.read_bytes()
        result = invoke([sys.executable, str(checker), str(self.root)])
        self.assertEqual(result.returncode, 1)
        self.assertIn("drift", result.stderr)
        self.assertEqual(path.read_bytes(), before)

    def test_rule_checker_rejects_missing_body(self) -> None:
        checker = ROOT / ".harness/scripts/check-agent-rules.py"
        for name in ("AGENTS.md", "CLAUDE.md"):
            (self.root / name).write_text("# unrelated\n")
        result = invoke([sys.executable, str(checker), str(self.root)])
        self.assertEqual(result.returncode, 1)
        self.assertIn("shared rule body", result.stderr)

    def test_shell_reader_complete_empty_and_missing(self) -> None:
        reader = ROOT / ".harness/scripts/read-error-journal.sh"
        journal = self.root / ".harness/error-journal.md"
        journal.parent.mkdir()
        content = "\n".join([f"line {i}" for i in range(350)] + ["最新错误 ERR-fixture"]) + "\n"
        for shell in ("/bin/sh", "/bin/bash"):
            for value in (content, ""):
                with self.subTest(shell=shell, empty=not value):
                    journal.write_text(value)
                    result = invoke([shell, str(reader), str(self.root)])
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout, value)
        journal.unlink()
        result = invoke(["/bin/sh", str(reader), str(self.root)])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing:", result.stderr)

    @unittest.skipUnless(shutil.which("pwsh"), "PowerShell not installed; runtime behavior unverified")
    def test_powershell_reader_tail(self) -> None:
        journal = self.root / ".harness/error-journal.md"
        journal.parent.mkdir()
        journal.write_text("line\n" * 350 + "LATEST_ENTRY\n")
        result = invoke([shutil.which("pwsh"), "-NoProfile", "-File",
                         str(ROOT / ".harness/scripts/read-error-journal.ps1"), "-RepoRoot", str(self.root)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("LATEST_ENTRY", result.stdout)


class DocumentPatchTests(IsolatedCase):
    def test_only_actual_document_targets_are_exempt(self) -> None:
        cases = [
            ("plain text", "*** Add File: canary.txt\n+HARNESS_RUNTIME_CANARY", True),
            ("markdown code example", "*** Update File: docs/note.md\n@@\n+modify handler.go", True),
            ("body looks like a target", "*** Add File: docs/note.md\n+*** Update File: handler.go", True),
            ("document move", "*** Update File: old.md\n*** Move to: new.md\n@@\n-a\n+b", True),
            ("mixed code", "*** Add File: note.md\n+note\n*** Add File: handler.go\n+package main", False),
            ("move to code", "*** Update File: old.md\n*** Move to: handler.go\n@@\n-a\n+b", False),
            ("move from code", "*** Update File: handler.go\n*** Move to: new.md\n@@\n-a\n+b", False),
            ("dependency text", "*** Add File: requirements.txt\n+package", False),
            ("build text", "*** Add File: CMakeLists.txt\n+project(x)", False),
            ("outside project", "*** Add File: ../outside.md\n+note", False),
            ("empty patch", "", False),
        ]
        with patch.object(common, "REPO_ROOT", self.root):
            for label, body, expected in cases:
                with self.subTest(case=label):
                    text = "*** Begin Patch\n" + body + "\n*** End Patch"
                    payload = {"tool_name": "apply_patch", "tool_input": {"command": text}, "cwd": str(self.root)}
                    self.assertEqual(common.documentation_tool_targets(payload), expected)
                    if expected:
                        with patch.object(common, "openspec_list", side_effect=AssertionError("document must not query OpenSpec")):
                            self.assertTrue(common.should_allow_tool(payload)[0])

    def test_legacy_payload_sources_and_incomplete_patch(self) -> None:
        text = "*** Begin Patch\n*** Add File: note.md\n+example.go\n*** End Patch"
        with patch.object(common, "REPO_ROOT", self.root):
            for field in ("patch", "input", "command"):
                with self.subTest(field=field):
                    payload = {"tool_name": "apply_patch", "tool_input": {field: text}, "cwd": str(self.root)}
                    self.assertTrue(common.documentation_tool_targets(payload))
            payload["tool_input"] = {"command": text.removesuffix("\n*** End Patch")}
            self.assertFalse(common.documentation_tool_targets(payload))


class ResolverTests(IsolatedCase):
    def setUp(self) -> None:
        super().setUp()
        self.env = patch.dict(os.environ, {}, clear=True)
        self.env.start()
        self.addCleanup(self.env.stop)
        self.home = patch.object(Path, "home", return_value=self.root)
        self.home.start()
        self.addCleanup(self.home.stop)

    def test_explicit_path_with_spaces_is_preserved(self) -> None:
        cli = executable(self.root / "CLI dir/openspec", "print('1.3.0-fixture')\n")
        with patch.dict(os.environ, {"OPENSPEC_BIN": str(cli)}):
            self.assertEqual(common.openspec_prefix(), [str(cli)])

    def test_invalid_override_does_not_use_valid_path(self) -> None:
        cli = executable(self.root / "openspec", "print('1.3.0-fixture')\n")
        with patch.dict(os.environ, {"OPENSPEC_BIN": str(self.root / "missing")}), patch.object(common.shutil, "which", return_value=str(cli)):
            with self.assertRaisesRegex(common.OpenSpecRuntimeError, "does not exist"):
                common.openspec_prefix()

    def test_path_installation_is_used(self) -> None:
        cli = executable(self.root / "openspec", "print('1.3.0-fixture')\n")
        with patch.object(common.shutil, "which", return_value=str(cli)):
            self.assertEqual(common.openspec_prefix(), [str(cli)])

    def test_existing_nvm_install_uses_compatible_node(self) -> None:
        base = self.root / ".nvm/versions/node"
        for version in ("v24.6.0", "v24.22.0"):
            cli = base / version / "lib/node_modules/@fission-ai/openspec/bin/openspec.js"
            cli.parent.mkdir(parents=True)
            cli.write_text("print('1.3.0-fixture')\n")
            executable(base / version / "bin/node", "import subprocess,sys\n"
                       f"print('{version[1:]}') if sys.argv[1]=='-p' else sys.exit(subprocess.run([{sys.executable!r},*sys.argv[1:]]).returncode)\n")
        broken = executable(self.root / "broken-path-cli", "raise SystemExit(7)\n")
        for on_path in (None, str(broken)):
            with self.subTest(on_path=on_path), patch.object(common.shutil, "which", side_effect=lambda name: on_path if name == "openspec" else None):
                result = common.openspec_prefix()
            self.assertIn("v24.22.0", result[0])
            self.assertIn("v24.22.0", result[1])

    def test_missing_and_nonzero_cli_are_controlled_errors(self) -> None:
        with patch.object(common.shutil, "which", return_value=None):
            with self.assertRaisesRegex(common.OpenSpecRuntimeError, "not installed"):
                common.openspec_prefix()
        cli = executable(self.root / "broken", "raise SystemExit(7)\n")
        with patch.dict(os.environ, {"OPENSPEC_BIN": str(cli)}):
            with self.assertRaisesRegex(common.OpenSpecRuntimeError, "exit 7"):
                common.openspec_prefix()

    def test_javascript_cli_requires_compatible_node(self) -> None:
        cli = self.root / "openspec.js"
        cli.write_text("fixture\n")
        node = executable(self.root / "node", "print('18.20.0')\n")
        with patch.dict(os.environ, {"OPENSPEC_BIN": str(cli)}), patch.object(common.shutil, "which", return_value=str(node)):
            with self.assertRaisesRegex(common.OpenSpecRuntimeError, "Node.js >=20.19.0"):
                common.openspec_prefix()

    def test_probe_timeout_is_controlled(self) -> None:
        cli = executable(self.root / "stuck", "import time\ntime.sleep(1)\n")
        with patch.dict(os.environ, {"OPENSPEC_BIN": str(cli)}), patch.object(common, "PROBE_TIMEOUT", 0.05):
            with self.assertRaisesRegex(common.OpenSpecRuntimeError, "timed out"):
                common.openspec_prefix()

    def test_command_timeout_and_os_error_are_wrapped(self) -> None:
        for failure in (subprocess.TimeoutExpired(["fixture"], 8), FileNotFoundError("fixture")):
            with self.subTest(failure=type(failure).__name__), patch.object(common, "openspec_prefix", return_value=["fixture"]), patch.object(common.subprocess, "run", side_effect=failure):
                with self.assertRaises(common.OpenSpecRuntimeError):
                    common.run_command(["openspec", "list", "--json"], self.root)


class HookCommandTests(IsolatedCase):
    def setUp(self) -> None:
        super().setUp()
        self.records = self.root / "diagnostics"
        self.addCleanup(self.retain_failed_fixture)
        for relative in (".openspec-auto/tools", ".openspec-auto/hooks", ".harness/hooks"):
            shutil.copytree(ROOT / relative, self.root / relative, ignore=shutil.ignore_patterns("__pycache__"))
        for relative in ("AGENTS.md", "CLAUDE.md", ".codex/hooks.json", ".claude/settings.json",
                         ".harness/scripts/check-agent-rules.py", ".agents/skills/openspec-auto/SKILL.md",
                         ".claude/skills/openspec-auto/SKILL.md", ".harness/scripts/workflow.py"):
            destination = self.root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, destination)
        (self.root / ".harness/VERSION").write_text("source-path:\n")
        (self.root / ".harness/error-journal.md").write_text(
            "## [ERR-fixture] test\n\n**Status**: open\n\n### Summary\nfixture latest error\n")
        self.state = self.root / "fixture-state.json"
        self.state.write_text(json.dumps({"changes": [], "ready": False}))
        self.cli = executable(self.root / "tools with spaces/openspec", "import json,os,sys\n"
            "args=sys.argv[1:]\n"
            "state=json.load(open(os.environ['HARNESS_FIXTURE_STATE']))\n"
            "if args==['--version']: print('1.3.0-fixture')\n"
            "elif args[0]=='list': print(json.dumps({'changes': state['changes']}))\n"
            "elif args[0]=='status': print(json.dumps({'applyRequires':['tasks'],'artifacts':[{'id':'tasks','status':'done' if state['ready'] else 'ready'}]}))\n"
            "elif args[0]=='echo-args': print(json.dumps(args[1:]))\n"
            "else: raise SystemExit(9)\n")
        self.env = {**os.environ, "OPENSPEC_BIN": str(self.cli), "OPENSPEC_PYTHON": sys.executable,
                    "HARNESS_FIXTURE_STATE": str(self.state), "PYTHONDONTWRITEBYTECODE": "1"}
        self.configs = [json.loads((self.root / relative).read_text())["hooks"]
                        for relative in (".codex/hooks.json", ".claude/settings.json")]
        # Instrument only this fixture copy; the configured hook command is unchanged.
        shutil.copy2(Path(__file__).with_name("fixture_diagnostics.py"),
                     self.root / ".openspec-auto/tools/fixture_diagnostics.py")
        with (self.root / ".openspec-auto/tools/hook_common.py").open("a", encoding="utf-8") as stream:
            stream.write("\nfrom fixture_diagnostics import SubprocessTrace\n"
                         f"subprocess = SubprocessTrace(subprocess, {str(self.records)!r}, {str(self.cli)!r})\n")

    def retain_failed_fixture(self) -> None:
        result = self._outcome.result
        failures = [trace for test, trace in result.failures + result.errors
                    if test is self or getattr(test, "test_case", None) is self]
        if failures:
            destination = getattr(self, "failure_root", ROOT / ".cache/harness-fixture-failures")
            snapshots = {"fixture-state.json": self.root / "fixture-state.json"}
            if hasattr(self, "cli"):
                snapshots["fake-cli.py"] = self.cli
            path = retain_failure(self.records, destination, self.id(), failures, snapshots)
            print(f"[fixture diagnostics] retained: {path}", file=sys.stderr)

    def invoke(self, args: list[str], *, kind: str = "command",
               details: dict | None = None, **kwargs: object) -> subprocess.CompletedProcess[str]:
        return record_process(self.records, kind, args, details=details, text=True,
                              capture_output=True, timeout=20, check=False, **kwargs)

    def activate_workflow(self) -> None:
        contract = {"schema_version": 1, "stage": "2", "change": "fixture-change",
            "allowed_files": [{"path": "cmd/server.go", "kind": "code"}, {"path": "handler.go", "kind": "code"}],
            "required_context": [],
            "checks": [{"id": "test", "kind": "functional", "argv": ["python3", "test_fixture.py"], "timeout_seconds": 2}],
            "regressions": []}
        (self.root / "plan.md").write_text(workflow.MARKER + "\n```json\n" + json.dumps(contract) + "\n```\n")
        store = workflow.SessionStore(self.root, "phase-one-fixture")
        workflow.record_request(store, "实施第二阶段代码")
        trace = SubprocessTrace(subprocess, self.records, self.cli)
        with contextlib.redirect_stdout(io.StringIO()), patch.dict(os.environ, self.env), patch.dict(common.OPEN_SPEC_ENV, self.env), patch.object(common, "subprocess", trace):
            workflow.read_context(store, "plan.md", "plan.md", 1, 1000)
            workflow.activate(store, "plan.md")

    def hooks(self, config: dict, event: str, payload: dict, target: str = "") -> list[dict]:
        outputs = []
        data = {"session_id": "phase-one-fixture", "cwd": str(self.root), "hook_event_name": event, **payload}
        for entry in config[event]:
            if event == "PreToolUse" and not re.fullmatch(entry["matcher"], data["tool_name"]):
                continue
            for hook in entry["hooks"]:
                if target and target not in hook["command"]:
                    continue
                client = next(index for index, value in enumerate(self.configs) if value is config)
                result = self.invoke(["/bin/sh", "-c", hook["command"]], kind="hook",
                                     details={"event": event, "client": client},
                                     input=json.dumps(data), cwd=self.root, env=self.env)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertNotIn("Traceback", result.stderr)
                outputs.append(json.loads(result.stdout))
        self.assertTrue(outputs, (event, target))
        return outputs

    def test_client_configs_and_start_prompt_stop_contracts(self) -> None:
        self.assertEqual(*self.configs)
        for index, config in enumerate(self.configs):
            with self.subTest(client=index):
                start = self.hooks(config, "SessionStart", {})
                contexts = [value["hookSpecificOutput"]["additionalContext"] for value in start]
                self.assertTrue(any("no active changes" in context for context in contexts), contexts)
                self.assertTrue(any("ERR-fixture" in context for context in contexts))
                routed = self.hooks(config, "UserPromptSubmit", {"prompt": "请修改 handler.go"})
                self.assertIn("create a new change", routed[0]["hookSpecificOutput"]["additionalContext"])
                self.hooks(config, "UserPromptSubmit", {"prompt": "只解释当前代码"})
                self.assertEqual(self.hooks(config, "Stop", {"last_assistant_message": "已完成解释"}), [{}])

    def test_guard_bash_and_apply_patch_before_and_after_ready(self) -> None:
        inputs = [("Bash", {"command": "sed -i '' cmd/server.go"}),
                  ("apply_patch", {"command": "*** Begin Patch\n*** Update File: cmd/server.go\n@@\n-old\n+new\n*** End Patch"})]
        for ready in (False, True):
            self.state.write_text(json.dumps({"changes": [{"name": "fixture-change"}], "ready": ready}))
            if ready:
                self.activate_workflow()
            for config in self.configs:
                for tool, tool_input in inputs:
                    with self.subTest(ready=ready, tool=tool):
                        output = self.hooks(config, "PreToolUse", {"tool_name": tool, "tool_input": tool_input}, "openspec_guard.py")[0]
                        if ready and tool == "apply_patch":
                            self.assertEqual(output, {})
                        else:
                            self.assertEqual(output["hookSpecificOutput"]["permissionDecision"], "deny")

    def test_document_write_exemption(self) -> None:
        for config in self.configs:
            result = self.hooks(config, "PreToolUse", {"tool_name": "Write", "tool_input": {
                "file_path": str(self.root / "docs/note.md"), "content": "请说明 cmd/server.go"}}, "openspec_guard.py")
            self.assertEqual(result, [{}])

    def test_workflow_cli_and_stop_require_real_execution_for_both_clients(self) -> None:
        self.state.write_text(json.dumps({"changes": [{"name": "fixture-change"}], "ready": True}))
        (self.root / "test_fixture.py").write_text("print('fixture execution')\n")
        script = self.root / ".harness/scripts/workflow.py"
        for config in self.configs:
            self.hooks(config, "UserPromptSubmit", {"prompt": "实施第二阶段代码"})
            self.activate_workflow()
            blocked = self.hooks(config, "Stop", {"last_assistant_message": "已完成"})[0]
            self.assertEqual(blocked["decision"], "block")
            for action in (["run", "--check", "test"], ["ready"], ["finish"]):
                result = self.invoke([sys.executable, str(script), "--session", "phase-one-fixture", *action],
                                env=self.env, cwd=self.root)
                self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(self.hooks(config, "Stop", {"last_assistant_message": "已完成"}), [{}])
            self.hooks(config, "UserPromptSubmit", {"prompt": "只更新 README 文档，不实施代码"})
            self.assertEqual(self.hooks(config, "Stop", {"last_assistant_message": "文档已完成"}), [{}])

    def test_followup_messages_preserve_only_active_workflow(self) -> None:
        self.state.write_text(json.dumps({"changes": [{"name": "fixture-change"}], "ready": True}))
        reply = "<send_user_message_question_reply>" + json.dumps([{
            "questionItemId": '["request_user_input_async","call_fixture",0]',
            "question": "是否继续实施？", "answer": "继续按已落盘修复方案实施并验收",
        }], ensure_ascii=False) + "</send_user_message_question_reply>"
        store = workflow.SessionStore(self.root, "phase-one-fixture")
        for client, config in enumerate(self.configs):
            with self.subTest(client=client):
                self.activate_workflow()
                before = store.read()
                for prompt in (reply, "子会话已经停止了", "尽快完成，不要在这里花费太多时间，完成后，清理所有临时项目"):
                    output = self.hooks(config, "UserPromptSubmit", {"prompt": prompt})[0]
                    self.assertIn("Recognized followup", output["hookSpecificOutput"]["additionalContext"])
                    after = store.read()
                    self.assertEqual(after["request"], before["request"])
                    self.assertEqual(after["revision"], before["revision"])
                    self.assertEqual(after["reads"], before["reads"])
                result = self.hooks(config, "PreToolUse", {"tool_name": "apply_patch", "tool_input": {
                    "command": "*** Begin Patch\n*** Add File: handler.go\n+package main\n*** End Patch"}}, "openspec_guard.py")
                self.assertEqual(result, [{}])
                self.assertEqual(self.hooks(config, "Stop", {})[0]["decision"], "block")
                self.hooks(config, "UserPromptSubmit", {"prompt": "只解释代码，不修改"})
                self.hooks(config, "UserPromptSubmit", {"prompt": "尽快完成"})
                self.assertFalse(store.read()["request"]["implementation"])
                result = self.hooks(config, "PreToolUse", {"tool_name": "apply_patch", "tool_input": {
                    "command": "*** Begin Patch\n*** Add File: handler.go\n+package main\n*** End Patch"}}, "openspec_guard.py")
                self.assertEqual(result[0]["hookSpecificOutput"]["permissionDecision"], "deny")

    def test_document_patch_command_exemption(self) -> None:
        for config in self.configs:
            for filename in ("docs/note.md", "canary.txt"):
                with self.subTest(filename=filename):
                    text = f"*** Begin Patch\n*** Add File: {filename}\n+说明 handler.go\n*** End Patch"
                    result = self.hooks(config, "PreToolUse", {"tool_name": "apply_patch", "tool_input": {
                        "command": text}}, "openspec_guard.py")
                    self.assertEqual(result, [{}])

    def test_mixed_document_and_code_still_requires_change(self) -> None:
        text = "*** Begin Patch\n*** Add File: note.md\n+note\n*** Add File: handler.go\n+package main\n*** End Patch"
        for config in self.configs:
            result = self.hooks(config, "PreToolUse", {"tool_name": "apply_patch", "tool_input": {
                "command": text}}, "openspec_guard.py")
            self.assertEqual(result[0]["hookSpecificOutput"]["permissionDecision"], "deny")

    def test_safety_contract_does_not_execute_dangerous_payloads(self) -> None:
        inputs = [("Bash", {"command": "git reset --hard"}),
                  ("apply_patch", {"command": "*** Begin Patch\n*** Update File: .git/config\n@@\n-x\n+y\n*** End Patch"})]
        for config in self.configs:
            for tool, tool_input in inputs:
                with self.subTest(tool=tool):
                    result = self.hooks(config, "PreToolUse", {"tool_name": tool, "tool_input": tool_input}, "pre_tool_use.py")
                    self.assertEqual(result[0]["hookSpecificOutput"]["permissionDecision"], "deny")
        self.assertFalse((self.root / ".git").exists())

    def test_missing_cli_denies_cleanly_without_traceback(self) -> None:
        self.state.write_text(json.dumps({"changes": [{"name": "fixture-change"}], "ready": True}))
        self.activate_workflow()
        self.env["OPENSPEC_BIN"] = str(self.root / "missing")
        for config in self.configs:
            result = self.hooks(config, "PreToolUse", {"tool_name": "Write", "tool_input": {
                "file_path": "handler.go", "content": "package main"}}, "openspec_guard.py")[0]
            self.assertEqual(result["hookSpecificOutput"]["permissionDecision"], "deny")
            self.assertIn("CLI state could not be read", result["hookSpecificOutput"]["permissionDecisionReason"])

    def test_shell_wrapper_preserves_argv_and_healthcheck_scopes_claims(self) -> None:
        argument = "spaces ; $(touch SHOULD_NOT_EXIST) ' quote"
        runner = self.root / ".openspec-auto/tools/run_openspec.py"
        result = self.invoke([sys.executable, str(runner), "echo-args", argument], env=self.env, cwd=self.root)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), [argument])
        env_file = self.root / ".openspec-auto/tools/env.sh"
        result = self.invoke(["/bin/bash", "-c", 'source "$1"; openspec_run echo-args "$2"', "fixture", str(env_file), argument], env=self.env, cwd=self.root)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), [argument])
        self.assertFalse((self.root / "SHOULD_NOT_EXIST").exists())
        healthcheck = self.root / ".openspec-auto/tools/healthcheck.sh"
        result = self.invoke(["/bin/bash", str(healthcheck), str(self.root)], env=self.env, cwd=self.root)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("activation is not established", result.stdout)
        path = self.root / ".claude/settings.json"
        data = json.loads(path.read_text())
        data["hooks"]["PreToolUse"][0]["matcher"] = "Write"
        path.write_text(json.dumps(data))
        result = self.invoke(["/bin/bash", str(healthcheck), str(self.root)], env=self.env, cwd=self.root)
        self.assertEqual(result.returncode, 1)
        self.assertIn("registrations differ", result.stderr)


class FixtureDiagnosticsTests(IsolatedCase):
    def test_full_output_and_nonzero_exit_are_preserved(self) -> None:
        records = self.root / "records"
        payload = "完整输出\n" * 12000
        argv = [sys.executable, "-c", "import sys; sys.stdout.write(sys.stdin.read()); "
                "sys.stderr.write('stderr 完整尾部\\n'); raise SystemExit(7)"]
        result = record_process(records, "hook", argv, input=payload, text=True,
                                capture_output=True, timeout=20, check=False, cwd=self.root)
        self.assertEqual(result.returncode, 7)
        self.assertEqual(result.stdout, payload)
        self.assertEqual(result.stderr, "stderr 完整尾部\n")
        record_path, = records.glob("*/record.json")
        data = json.loads(record_path.read_text())
        self.assertEqual(data["argv"], argv)
        self.assertEqual(data["exit_code"], 7)
        self.assertEqual(data["status"], "exited")
        self.assertEqual(data["timeout_seconds"], 20)
        self.assertGreaterEqual(data["duration_seconds"], 0)
        self.assertEqual((record_path.parent / "stdin").read_text(), payload)
        self.assertEqual((record_path.parent / "stdout").read_text(), result.stdout)
        self.assertEqual((record_path.parent / "stderr").read_text(), result.stderr)

    def test_exception_identity_partial_bytes_and_exit_status_are_preserved(self) -> None:
        argv = [str(self.root / "missing-cli")]
        failures = [
            (subprocess.TimeoutExpired(argv, 2, output=b"\xffpartial\n", stderr=b"timeout stderr"), "timeout", None),
            (FileNotFoundError(2, "missing fixture CLI", argv[0]), "os_error", None),
            (subprocess.CalledProcessError(9, argv, output=b"bad exit", stderr=b"details"), "error", 9),
        ]
        for index, (error, status, code) in enumerate(failures):
            with self.subTest(status=status):
                def fail(*args: object, **kwargs: object) -> None:
                    raise error
                directory = self.root / str(index)
                with self.assertRaises(type(error)) as caught:
                    record_process(directory, "cli", argv, runner=fail, timeout=2)
                self.assertIs(caught.exception, error)
                path, = directory.glob("*/record.json")
                record = json.loads(path.read_text())
                self.assertEqual(record["status"], status)
                self.assertEqual(record["exit_code"], code)
                self.assertEqual((path.parent / "stdout").read_bytes(), getattr(error, "stdout", None) or b"")
                self.assertEqual((path.parent / "stderr").read_bytes(), getattr(error, "stderr", None) or b"")

    def test_failures_survive_cleanup_and_success_keeps_no_artifact(self) -> None:
        class FixtureCase(HookCommandTests):
            fault = "success"

            def runTest(self) -> None:
                if self.fault == "json":
                    (self.root / ".openspec-auto/hooks/openspec_context.py").write_text("print('not JSON')\n")
                elif self.fault == "cli":
                    executable(self.cli, "import sys\n"
                               "if sys.argv[1:] == ['--version']: print('1.3.0-fixture')\n"
                               "else: print('CLI stderr details', file=sys.stderr); raise SystemExit(7)\n")
                output = self.hooks(self.configs[0], "SessionStart", {}, "openspec_context.py")
                with self.subTest(phase="diagnostic"):
                    if self.fault == "assert":
                        self.fail("intentional diagnostic failure")
                    self.assertIn("no active changes", output[0]["hookSpecificOutput"]["additionalContext"])

        destination = self.root / "retained"
        seen: set[Path] = set()
        for fault in ("success", "assert", "assert", "json", "cli"):
            with self.subTest(fault=fault):
                case = FixtureCase()
                case.fault = fault
                case.failure_root = destination
                result = unittest.TestResult()
                message = io.StringIO()
                with contextlib.redirect_stderr(message):
                    case.run(result)
                self.assertFalse(case.root.exists())
                if fault == "success":
                    self.assertTrue(result.wasSuccessful())
                    self.assertFalse(destination.exists())
                    continue
                self.assertFalse(result.wasSuccessful())
                added = set(destination.iterdir()) - seen
                self.assertEqual(len(added), 1)
                retained, = added
                seen.add(retained)
                self.assertIn(str(retained.resolve()), message.getvalue())
                failure = json.loads((retained / "failure.json").read_text())
                self.assertTrue(failure["failures"])
                self.assertTrue((retained / "fixture-state.json").is_file())
                self.assertTrue((retained / "fake-cli.py").is_file())
                paths = list((retained / "processes").glob("*/record.json"))
                records = [(path, json.loads(path.read_text())) for path in paths]
                hook_path, hook = next(item for item in records if item[1]["kind"] == "hook")
                self.assertEqual(hook["exit_code"], 0)
                self.assertEqual(hook["details"], {"event": "SessionStart", "client": 0})
                self.assertEqual(json.loads((hook_path.parent / "stdin").read_text())["session_id"], "phase-one-fixture")
                if fault == "json":
                    self.assertEqual((hook_path.parent / "stdout").read_text(), "not JSON\n")
                    self.assertIn("JSONDecodeError", "".join(failure["failures"]))
                    continue
                cli = [(path, record) for path, record in records if record["kind"] == "cli"]
                self.assertEqual(sorted(record["argv"][1:] for _, record in cli), [["--version"], ["list", "--json"]])
                for _, record in cli:
                    self.assertGreaterEqual(record["duration_seconds"], 0)
                if fault == "cli":
                    path, record = next(item for item in cli if item[1]["exit_code"] == 7)
                    self.assertTrue(record["stderr_merged"])
                    self.assertEqual((path.parent / "stdout").read_text(), "CLI stderr details\n")
                    self.assertFalse(record["stderr"]["available"])
                else:
                    self.assertTrue(all(record["exit_code"] == 0 for _, record in cli))
        self.assertEqual(len(seen), 4)

    def test_recording_failure_is_explicit_and_does_not_start_a_command(self) -> None:
        directory = self.root / "not-a-directory"
        directory.write_text("occupied")
        with patch.object(subprocess, "run") as runner:
            with self.assertRaises(FileExistsError):
                record_process(directory, "hook", ["unused"], runner=runner)
        runner.assert_not_called()


if __name__ == "__main__":
    unittest.main(verbosity=2)
