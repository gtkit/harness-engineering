"""Metadata migration tests; simulated project/backup writes stay in memory."""
from __future__ import annotations

from contextlib import nullcontext, redirect_stdout, redirect_stderr
import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]


def load_module(name: str, relative: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / relative)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


updater = load_module("metadata_updater", "scripts/safe_update.py")
hook = load_module("metadata_hook", "scripts/hooks/session_start.py")


class MemoryBackup:
    """Only the backup filesystem boundary is replaced, not update logic."""
    def __init__(self, files: dict, name: str = "backup") -> None:
        self.files, self.name = files, name

    def __truediv__(self, part):
        return MemoryBackup(self.files, self.name + "/" + str(part))

    def __str__(self):
        return self.name

    @property
    def parent(self):
        return MemoryBackup(self.files, self.name.rsplit("/", 1)[0])

    def mkdir(self, **kwargs):
        pass

    def write_bytes(self, data):
        self.files[self.name] = (data, 0o600)

    def read_bytes(self):
        return self.files[self.name][0]

    def chmod(self, mode):
        self.files[self.name] = (self.read_bytes(), mode)

    def stat(self):
        return SimpleNamespace(st_mode=self.files[self.name][1])


class MetadataTests(unittest.TestCase):
    def setUp(self) -> None:
        self.guide = ".harness/guides/example.md"
        self.current = {
            "schema": 1, "component": "harness", "kind": "go-mcp-harness",
            "version": "111111111111", "revision": "1" * 40,
            "source_path": None, "tag": None,
            "files": {self.guide: updater.packed(updater.entry(b"new\n"))},
        }
        legacy = copy.deepcopy(self.current)
        legacy["source_path"] = str(ROOT)
        legacy["files"][self.guide] = updater.packed(updater.entry(b"old\n"))
        self.files = {
            self.guide: updater.entry(b"old\n"),
            ".harness/update-base.json": updater.entry(updater.json_bytes(legacy), 0o600),
            ".harness/VERSION": updater.entry((
                "harness: go-mcp-harness\nsource-commit: 111111111111\n"
                f"source-path: {ROOT}\ncustom: keep\n"
            ).encode(), 0o600),
        }

    def run_update(self, *, dry_run=False, fail_on=None):
        def write(root, rel, value, created):
            if rel == fail_on:
                raise OSError("injected write failure")
            if value is None:
                self.files.pop(rel, None)
            else:
                self.files[rel] = value

        with patch.object(updater, "snapshot", return_value=self.current), \
                patch.object(updater, "project_file", side_effect=lambda root, rel: self.files.get(rel)), \
                patch.object(updater, "atomic_write", side_effect=write) as writes, \
                patch.object(updater, "locked", return_value=nullcontext()), \
                patch.object(updater.Path, "home", return_value=MemoryBackup({})), \
                redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            result = updater.update(ROOT, [("harness", ROOT, "go-mcp-harness")], dry_run)
        return result, writes.call_count

    def test_real_snapshot_retains_schema_without_source_path(self):
        for kind in ("go-mcp-harness", "ts-mcp-harness"):
            with self.subTest(kind=kind):
                snapshot = updater.snapshot("harness", ROOT, kind)
                self.assertEqual(snapshot["schema"], 1)
                self.assertIsNone(snapshot["source_path"])
                self.assertEqual(snapshot["kind"], kind)
                for local in (str(ROOT), str(Path.home())):
                    self.assertNotIn(local.encode(), updater.json_bytes(snapshot))

    def test_legacy_update_migrates_metadata_preserves_fields_and_is_idempotent(self):
        result, writes = self.run_update()
        self.assertEqual(result, 0)
        self.assertGreater(writes, 0)
        self.assertEqual(self.files[self.guide][0], b"new\n")
        version, mode = self.files[".harness/VERSION"]
        self.assertNotIn(b"source-path:", version)
        self.assertIn(b"custom: keep\n", version)
        self.assertEqual(mode, 0o600)
        baseline = json.loads(self.files[".harness/update-base.json"][0])
        self.assertIsNone(baseline["source_path"])
        before = self.files.copy()
        self.assertEqual(self.run_update(), (0, 0))
        self.assertEqual(self.files, before)

    def test_dry_run_leaves_legacy_metadata_unchanged(self):
        before = self.files.copy()
        self.assertEqual(self.run_update(dry_run=True), (0, 0))
        self.assertEqual(self.files, before)

    def test_failed_update_restores_original_metadata(self):
        before = self.files.copy()
        with self.assertRaisesRegex(OSError, "injected"):
            self.run_update(fail_on=".harness/update-base.json")
        self.assertEqual(self.files, before)

    def test_conflict_does_not_migrate_metadata_or_overwrite_local_file(self):
        legacy = json.loads(self.files[".harness/update-base.json"][0])
        legacy["files"] = {}
        self.files[".harness/update-base.json"] = updater.entry(updater.json_bytes(legacy), 0o600)
        self.files[self.guide] = updater.entry(b"user-owned addition\n")
        before = self.files.copy()
        with self.assertRaises(updater.UpdateError):
            self.run_update()
        self.assertEqual(self.files, before)

    def test_empty_legacy_source_field_is_removed_without_losing_adjacent_fields(self):
        self.files[".harness/VERSION"] = updater.entry(
            b"harness: go-mcp-harness\nsource-path:\nsource-commit: 111111111111\ncustom: keep\n"
        )
        with patch.object(updater, "project_file", side_effect=lambda root, rel: self.files.get(rel)):
            _, value = updater.version_entry(ROOT, self.current, "harness", False)
        self.assertNotIn(b"source-path:", value[0])
        self.assertIn(b"source-commit: 111111111111\n", value[0])
        self.assertIn(b"custom: keep\n", value[0])

    def test_pre_baseline_install_uses_commit_not_legacy_source_path(self):
        self.files.pop(".harness/update-base.json")
        with patch.object(updater, "project_file", side_effect=lambda root, rel: self.files.get(rel)), \
                patch.object(updater, "templates", return_value={}) as templates:
            updater.baseline("harness", ROOT, ROOT, "go-mcp-harness")
        templates.assert_called_once_with("harness", ROOT, "go-mcp-harness", "111111111111")

    @unittest.skipUnless(shutil.which("bash"), "Bash unavailable")
    def test_bash_first_install_metadata_contains_no_source_path(self):
        # Execute the actual formatting block without its file redirection or installer.
        source = (ROOT / "scripts/install-harness.sh").read_text()
        start = source.index("    {\n        printf 'harness:")
        end = source.index('    } > "${version_file}"', start)
        block = source[start:end] + "    }\n"
        env = {**os.environ, "module_name": "go-mcp-harness", "harness_root": str(ROOT),
               "source_commit": "111111111111", "source_tag": "v1.0.0", "installed_at": "fixture-time"}
        result = subprocess.run([shutil.which("bash"), "-c", block], env=env,
                                capture_output=True, text=True, timeout=10, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("harness: go-mcp-harness\n", result.stdout)
        self.assertIn("source-commit: 111111111111\n", result.stdout)
        self.assertNotIn("source-path:", result.stdout)
        self.assertNotIn(str(ROOT), result.stdout)


class SessionSourceTests(unittest.TestCase):
    def invoke(self, version, environment, entries=()):
        output = io.StringIO()
        with patch.object(hook, "read_version", return_value=version), \
                patch.object(hook, "open_entries", return_value=list(entries)), \
                patch.object(hook, "template_head", return_value="new") as head, \
                patch.dict(os.environ, environment, clear=True), \
                patch.object(sys, "stdin", io.StringIO("{}")), redirect_stdout(output):
            self.assertEqual(hook.main(), 0)
        return head.call_args.args[0], output.getvalue()

    def test_runtime_source_has_priority_and_legacy_is_fallback(self):
        version = {"source-path": "legacy-source", "source-commit": "old", "harness": "go-mcp-harness"}
        source, output = self.invoke(version, {"HARNESS_SOURCE_DIR": "runtime-source"})
        self.assertEqual(source, "runtime-source")
        self.assertIn("go-mcp-harness update", output)
        self.assertEqual(self.invoke(version, {})[0], "legacy-source")
        self.assertEqual(self.invoke(version, {"HARNESS_SOURCE_DIR": ""})[0], "legacy-source")

    def test_no_source_preserves_error_memory(self):
        source, output = self.invoke({}, {}, ["ERR-fixture: remembered"])
        self.assertEqual(source, "")
        self.assertIn("ERR-fixture", output)
        self.assertNotIn("模板已更新", output)

    def test_empty_source_does_not_invoke_git(self):
        with patch.object(hook.subprocess, "run") as run:
            self.assertEqual(hook.template_head(""), "")
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main(verbosity=2)
