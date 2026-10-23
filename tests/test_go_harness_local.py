#!/usr/bin/env python3
"""Local generation regression. Uses existing tools; no downloads or Go gates."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
OPENSPEC = ROOT.parent / "openspec-auto-bootstrap"
spec = importlib.util.spec_from_file_location("local_updater", ROOT / "scripts/safe_update.py")
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)
WORKFLOW_FILES = {".harness/scripts/workflow.py", ".harness/guides/workflow-contract.md",
                  ".harness/guides/workflow-plan-example.md"}


class DistributionTests(unittest.TestCase):
    def test_profile_assets_override_shared_skills(self) -> None:
        files = updater.templates("harness", ROOT, "go-harness")
        for name in ("harness-plan", "harness-implement"):
            expected = (ROOT / "go-harness/skills" / name / "SKILL.md").read_bytes()
            for client in (".agents", ".claude"):
                self.assertEqual(files[f"{client}/skills/{name}/SKILL.md"][0], expected)
        for name in ("check-agent-rules.py", "test_runtime_wiring.py",
                     "test_workflow_contract.py", "fixture_diagnostics.py"):
            self.assertEqual(files[f".harness/scripts/{name}"][0],
                             (ROOT / "go-harness/scripts" / name).read_bytes())
        self.assertFalse(WORKFLOW_FILES.intersection(files))

    def test_openspec_owns_only_declared_workflow_files(self) -> None:
        files = updater.templates("openspec", OPENSPEC)
        self.assertTrue(WORKFLOW_FILES.issubset(files))
        for name in WORKFLOW_FILES:
            self.assertEqual(updater.owned("openspec", name), name)
        for name in (".harness/error-journal.md", ".harness/scripts/arbitrary.py"):
            with self.assertRaises(updater.UpdateError):
                updater.owned("openspec", name)
        self.assertFalse(any(name.startswith(".openspec-auto/state/") for name in files))

    def test_two_client_rule_blocks_match(self) -> None:
        self.assertEqual((OPENSPEC / "templates/repo/AGENTS.md").read_bytes(),
                         (OPENSPEC / "templates/repo/CLAUDE.md").read_bytes())

    def test_update_engines_stay_identical(self) -> None:
        self.assertEqual((ROOT / "scripts/safe_update.py").read_bytes(),
                         (OPENSPEC / "safe_update.py").read_bytes())


def integration(output: Path, legacy: Path | None) -> None:
    sys.path.insert(0, str(OPENSPEC / "templates/repo/.openspec-auto/tools"))
    from hook_common import openspec_prefix

    # Resolve before isolating the child user directory; no process-global env change.
    prefix = openspec_prefix()
    output.mkdir(parents=True, exist_ok=True)
    private = output / "isolated-user"
    private.mkdir()
    binaries = output / "bin"
    binaries.mkdir()
    shim = binaries / "openspec"
    shim.write_text("#!/bin/sh\nexec " + shlex.join(prefix) + ' "$@"\n')
    shim.chmod(0o700)
    env = {**os.environ, "HOME": str(private), "XDG_CONFIG_HOME": str(private / ".config"),
           "PATH": str(binaries) + os.pathsep + os.environ.get("PATH", ""),
           "OPENSPEC_BIN": str(shim), "OPENSPEC_PYTHON": sys.executable,
           "OPENSPEC_AUTO_BOOTSTRAP_DIR": str(OPENSPEC), "OPENSPEC_TELEMETRY": "0",
           "PYTHONDONTWRITEBYTECODE": "1"}
    env.pop("CODEX_HOME", None)
    records: list[dict] = []

    def run(label: str, argv: list[str], cwd: Path) -> None:
        started = time.monotonic()
        try:
            result = subprocess.run(argv, cwd=cwd, env=env, capture_output=True, timeout=90, check=False)
        except (OSError, subprocess.TimeoutExpired) as exc:
            # Keep available partial output and re-raise the real failure.
            (output / f"{label}.stdout").write_bytes(getattr(exc, "stdout", None) or b"")
            (output / f"{label}.stderr").write_bytes(getattr(exc, "stderr", None) or b"")
            records.append({"label": label, "argv": argv, "cwd": str(cwd), "exit_code": None,
                            "elapsed_seconds": time.monotonic() - started, "error": str(exc)})
            (output / "commands.json").write_text(json.dumps(records, indent=2) + "\n")
            raise
        (output / f"{label}.stdout").write_bytes(result.stdout)
        (output / f"{label}.stderr").write_bytes(result.stderr)
        records.append({"label": label, "argv": argv, "cwd": str(cwd), "exit_code": result.returncode,
                        "elapsed_seconds": time.monotonic() - started})
        (output / "commands.json").write_text(json.dumps(records, indent=2) + "\n")
        print(f"{label}: exit={result.returncode}; {records[-1]['elapsed_seconds']:.3f}s", flush=True)
        if result.returncode:
            raise RuntimeError(f"{label} failed; complete output retained in {output}")

    command = shutil.which("go-harness")
    if not command:
        raise RuntimeError("go-harness is not installed; no automatic installation performed")
    fresh = output / "fresh project"
    fresh.mkdir()
    run("new", [command, str(fresh), "--", "--skip-codex-user-config"], ROOT)
    upgraded = output / "updated project"
    if legacy is not None:
        if not (legacy / ".harness/local-generation-fixture").is_file():
            raise RuntimeError("legacy input must be a disposable, explicitly marked generation fixture")
        shutil.copytree(legacy, upgraded)
    else:
        shutil.copytree(fresh, upgraded)
    for name in ("AGENTS.md", "CLAUDE.md"):
        p = upgraded / name
        p.write_text(p.read_text().replace("\n", "\nLocal-only preamble retained.\n", 1))
    canaries = {"business-canary.txt": b"user content\n",
                ".openspec-auto/state/local-canary.json": b'{"local": true}\n'}
    journal = upgraded / ".harness/error-journal.md"
    journal.write_bytes(journal.read_bytes() + b"\nLocal journal sentinel.\n")
    canaries[".harness/error-journal.md"] = journal.read_bytes()
    for name, data in canaries.items():
        p = upgraded / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data)
    hook_output = {"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "local hook"}}
    user_hook = {"matcher": ".*", "hooks": [{"type": "command",
                 "command": "printf '%s' " + shlex.quote(json.dumps(hook_output)), "timeout": 2}]}
    for name in (".claude/settings.json", ".codex/hooks.json"):
        p = upgraded / name
        value = json.loads(p.read_bytes())
        value["hooks"]["SessionStart"].append(user_hook)
        p.write_text(json.dumps(value, indent=2) + "\n")
    run("update", [command, "update", str(upgraded)], ROOT)
    for name, data in canaries.items():
        if (upgraded / name).read_bytes() != data:
            raise AssertionError(f"user file overwritten: {name}")
    for name in ("AGENTS.md", "CLAUDE.md"):
        if "Local-only preamble retained." not in (upgraded / name).read_text():
            raise AssertionError(f"user preamble overwritten: {name}")
    for name in (".claude/settings.json", ".codex/hooks.json"):
        if user_hook not in json.loads((upgraded / name).read_bytes())["hooks"]["SessionStart"]:
            raise AssertionError(f"user hook overwritten: {name}")

    mappings = {**updater.templates("harness", ROOT, "go-harness"),
                **updater.templates("openspec", OPENSPEC)}
    special = {"AGENTS.md", "CLAUDE.md", ".claude/settings.json", ".codex/hooks.json"}
    for label, project in (("new", fresh), ("updated", upgraded)):
        for name, (data, _) in mappings.items():
            if name not in special and (project / name).read_bytes() != data:
                raise AssertionError(f"distribution mismatch: {label}/{name}")
        for script in ("test_runtime_wiring.py", "test_workflow_contract.py"):
            run(label + "-" + script, [sys.executable, str(project / ".harness/scripts" / script)], project)
    digest = lambda: {name: hashlib.sha256((upgraded / name).read_bytes()).hexdigest() for name in mappings}
    before = digest()
    run("repeat-update", [command, "update", str(upgraded)], ROOT)
    if digest() != before:
        raise AssertionError("repeated update changed managed content")
    print(f"Local generation evidence: {output}", flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--integration", action="store_true", help="generate and update isolated projects with installed tools")
    parser.add_argument("--output", type=Path, help="new directory for persistent logs and disposable fixtures")
    parser.add_argument("--legacy-project", type=Path, help="marked disposable pre-update fixture to copy, never update in place")
    args = parser.parse_args()
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(DistributionTests))
    if not result.wasSuccessful():
        return 1
    if args.integration:
        output = args.output or Path(tempfile.mkdtemp(prefix="go-harness-local-")) / "evidence"
        try:
            integration(output.resolve(), args.legacy_project.resolve() if args.legacy_project else None)
        except (OSError, RuntimeError, AssertionError, subprocess.TimeoutExpired) as exc:
            print(f"Local generation failed: {exc}", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
