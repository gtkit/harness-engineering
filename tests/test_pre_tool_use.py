from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("pre_tool_use", ROOT / "scripts/hooks/pre_tool_use.py")
hook = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(hook)


class PreToolUseTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="harness hook test ")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name).resolve()
        self.project = self.root / "project with spaces"
        self.home = self.root / "home"
        self.project.mkdir()
        self.home.mkdir()
        for patch in (mock.patch.object(hook, "ROOT", self.project),
                      mock.patch.object(Path, "home", return_value=self.home),
                      mock.patch.dict(os.environ, {"HOME": str(self.home)})):
            patch.start()
            self.addCleanup(patch.stop)

    def invoke(self, tool, tool_input, cwd=None):
        payload = {"tool_name": tool, "tool_input": tool_input, "cwd": str(cwd or self.project)}
        output, error = io.StringIO(), io.StringIO()
        with mock.patch.object(hook.sys, "stdin", io.StringIO(json.dumps(payload))), contextlib.redirect_stdout(output), contextlib.redirect_stderr(error):
            try:
                hook.main()
            except SystemExit as exc:
                self.assertEqual(exc.code, 0)
        self.assertEqual(error.getvalue(), "")
        return json.loads(output.getvalue())

    def patch(self, body, cwd=None):
        command = "*** Begin Patch\n" + body + "\n*** End Patch"
        return self.invoke("apply_patch", {"command": command}, cwd)

    def assertDenied(self, result):
        self.assertEqual(result.get("hookSpecificOutput", {}).get("permissionDecision"), "deny", result)
        self.assertEqual(result["hookSpecificOutput"]["hookEventName"], "PreToolUse")

    def test_original_apply_patch_regression(self):
        self.assertDenied(self.patch("*** Add File: fixtures/.git/probe.txt\n+probe"))

    def test_protected_source_operations(self):
        for action, body in [("Add", "\n+new"), ("Delete", ""), ("Update", "\n@@\n-old\n+new")]:
            for path in [".git/config", str(self.home / ".codex/config.toml"), "/etc/harness-probe"]:
                with self.subTest(action=action, path=path):
                    self.assertDenied(self.patch(f"*** {action} File: {path}" + body))

    def test_ordinary_operations_and_spaces_are_allowed(self):
        for body in ["*** Add File: notes with spaces.txt\n+new", "*** Delete File: old.txt",
                     "*** Update File: notes.txt\n@@\n-old\n+new\n*** End of File",
                     "*** Update File: source.txt\n*** Move to: folder/target with spaces.txt\n@@\n-old\n+new"]:
            with self.subTest(body=body):
                self.assertEqual(self.patch(body), {})

    def test_control_header_trailing_whitespace_cannot_hide_paths(self):
        for action, body in [("Add", "\n+new"), ("Delete", ""), ("Update", "\n@@\n-old\n+new")]:
            for path in [".git", str(self.home / ".zshrc")]:
                with self.subTest(action=action, path=path):
                    self.assertDenied(self.patch(f"*** {action} File: {path} \t" + body))
        self.assertDenied(self.patch("*** Update File: safe.txt\n*** Move to: .git \t\n@@\n-old\n+new"))
        self.assertEqual(self.patch("*** Add File: normal file.txt \t\n+text"), {})

    def test_move_checks_both_source_and_destination(self):
        for source, target in [("safe.txt", ".git/moved.txt"), (".git/config", "safe.txt"),
                               ("safe.txt", str(self.home / ".agents/skills/probe/SKILL.md"))]:
            with self.subTest(source=source, target=target):
                self.assertDenied(self.patch(f"*** Update File: {source}\n*** Move to: {target}\n@@\n-old\n+new"))

    def test_late_protected_operation_denies_the_whole_patch(self):
        self.assertDenied(self.patch("*** Add File: safe.txt\n+allowed\n*** Delete File: .git/config"))

    def test_every_move_destination_is_checked(self):
        self.assertDenied(self.patch("*** Update File: first.txt\n*** Move to: safe.txt\n@@\n-old\n+new\n*** Update File: second.txt\n*** Move to: .git/config\n@@\n-old\n+new"))

    def test_text_content_is_not_a_target_or_shell_command(self):
        self.assertEqual(self.patch("*** Add File: docs.txt\n+*** Delete File: /etc/config\n+*** Move to: .git/config\n+git reset --hard\n+rm -rf /"), {})
        self.assertEqual(self.patch("*** Update File: docs.txt\n@@\n-*** Delete File: .git/config\n+*** Add File: /etc/config\n *** Move to: .git/config"), {})

    def test_relative_paths_use_event_cwd(self):
        child = self.project / "nested"
        child.mkdir()
        self.assertDenied(self.patch("*** Add File: ../.git/config\n+probe", child))
        self.assertEqual(self.patch("*** Add File: ../safe.txt\n+probe", child), {})
        self.assertDenied(self.patch("*** Add File: ./.git/config\n+probe"))

    def test_parent_components_cannot_hide_a_protected_path(self):
        self.assertDenied(self.patch("*** Add File: notes/../.git/config\n+probe"))
        target = self.home / ".codex/config.toml"
        self.assertDenied(self.patch(f"*** Add File: {self.project}/../home/.codex/config.toml\n+probe"))
        self.assertDenied(self.invoke("Write", {"file_path": str(target)}))

    def test_symlink_target_is_checked(self):
        protected = self.home / ".codex"
        protected.mkdir()
        (self.project / "alias").symlink_to(protected, target_is_directory=True)
        self.assertDenied(self.patch("*** Add File: alias/config.toml\n+probe"))

    def test_symlink_then_parent_uses_filesystem_resolution_order(self):
        nested = self.home / ".codex/nested"
        nested.mkdir(parents=True)
        (self.project / "alias").symlink_to(nested, target_is_directory=True)
        self.assertDenied(self.patch("*** Add File: alias/../config.toml\n+probe"))

    def test_protected_lexical_path_is_not_erased_by_symlink(self):
        safe = self.project / "safe"
        safe.mkdir()
        (self.project / ".git").symlink_to(safe, target_is_directory=True)
        self.assertDenied(self.patch("*** Add File: .git/config\n+probe"))

    def test_symlink_loop_is_denied_instead_of_throwing(self):
        (self.project / "loop").symlink_to("loop")
        self.assertDenied(self.patch("*** Add File: loop/config\n+probe"))

    def test_home_prefix_neighbor_is_allowed(self):
        neighbor = self.root / "home-neighbor/.codex/config.toml"
        self.assertEqual(self.patch(f"*** Add File: {neighbor}\n+probe"), {})
        self.assertEqual(self.patch("*** Add File: ordinary/.codex/probe.txt\n+probe"), {})

    def test_tilde_and_exact_protected_directories(self):
        for path in ["~/.gitconfig", "~/.codex/config.toml", str(self.home / ".ssh"), "/etc", ".git"]:
            with self.subTest(path=path):
                self.assertDenied(self.invoke("Write", {"file_path": path}))

    def test_missing_or_non_string_command_is_denied(self):
        for value in [{}, {"command": None}, {"command": []}, "raw unsupported payload"]:
            with self.subTest(value=value):
                self.assertDenied(self.invoke("apply_patch", value))

    def test_unrecognized_or_incomplete_patch_is_denied(self):
        commands = ["", "not a patch", "*** Begin Patch\n*** Add File: safe\n+content",
                    "*** Begin Patch\n*** Rename File: safe\n*** End Patch",
                    "*** Begin Patch\n*** Add File: \n+content\n*** End Patch",
                    "*** Begin Patch\n*** Add File: bad\0path\n+x\n*** End Patch",
                    "*** Begin Patch\n*** Move to: .git/config\n*** End Patch",
                    "*** Begin Patch\n*** Update File: a\n@@\n-old\n+new\n*** Move to: b\n*** End Patch",
                    "*** Begin Patch\n*** Update File: a\n*** Move to: b\n*** Move to: c\n*** End Patch",
                    "*** Begin Patch\n*** Add File: safe\nunprefixed content\n*** End Patch"]
        for command in commands:
            with self.subTest(command=command):
                self.assertDenied(self.invoke("apply_patch", {"command": command}))

    def test_safe_empty_patch_is_a_noop(self):
        self.assertEqual(self.invoke("apply_patch", {"command": "*** Begin Patch\n*** End Patch"}), {})

    def test_old_file_tools_share_path_protection(self):
        for tool in ["Write", "Edit", "MultiEdit", "NotebookEdit"]:
            with self.subTest(tool=tool):
                key = "notebook_path" if tool == "NotebookEdit" else "file_path"
                self.assertDenied(self.invoke(tool, {key: ".git/config"}))
                self.assertEqual(self.invoke(tool, {key: "notes.txt"}), {})

    def test_bash_denial_and_inert_documentation_regression(self):
        self.assertDenied(self.invoke("Bash", {"command": "git reset --hard --harness-probe-invalid-option"}))
        self.assertEqual(self.invoke("Bash", {"command": "pwd"}), {})
        self.assertEqual(self.invoke("Bash", {"command": "printf '%s' 'git reset --hard'"}), {})


if __name__ == "__main__":
    unittest.main()
