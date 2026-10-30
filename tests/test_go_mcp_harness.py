"""Exercise MCP template distribution from this repository without installing it."""
from __future__ import annotations

import importlib.util
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import unittest

# Importing the renderer must not leave local paths in .pyc artifacts.
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("mcp_distribution", ROOT / "scripts/safe_update.py")
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)


class MCPDistributionTests(unittest.TestCase):
    profile_name = "go-mcp-harness"
    language_guide = "go-modern.md"

    @classmethod
    def setUpClass(cls) -> None:
        cls.profile = ROOT / cls.profile_name
        cls.files = updater.templates("harness", ROOT, cls.profile_name)

    def test_both_transports_and_specialized_acceptance_are_distributed(self) -> None:
        required = {
            "architecture.md", "dependencies.md", "mcp-contracts.md", "mcp-stdio.md",
            "mcp-streamable-http.md", "mcp-security.md", "observability.md",
            "testing-and-validation.md", "acceptance-gates.md", "release-and-distribution.md",
            "review-checklist.md", self.language_guide, "skills-index.md",
        }
        for name in required:
            with self.subTest(guide=name):
                self.assertEqual(self.files[f".harness/guides/{name}"][0],
                                 (self.profile / "guides" / name).read_bytes())
        self.assertNotEqual(self.files[".harness/guides/acceptance-gates.md"][0],
                            (ROOT / "shared/guides/common/acceptance-gates.md").read_bytes())

    def test_guide_references_resolve_and_entries_cover_installed_guides(self) -> None:
        entries = [self.files[name][0].decode() for name in ("AGENTS.md", "CLAUDE.md")]
        pattern = r"\.harness/guides/[a-z0-9-]+\.md"
        for name, (data, _) in self.files.items():
            if name.endswith(".md"):
                for target in re.findall(pattern, data.decode()):
                    with self.subTest(source=name, target=target):
                        self.assertIn(target, self.files)
            if name.startswith(".harness/guides/"):
                for entry in entries:
                    self.assertIn(name, entry)

    def test_entry_bodies_are_identical_and_visible_to_git(self) -> None:
        agents = self.files["AGENTS.md"][0].decode()
        claude = self.files["CLAUDE.md"][0].decode()
        self.assertEqual(agents[agents.index("\n## "):], claude[claude.index("\n## "):])
        for entry in ("AGENTS.md", "CLAUDE.md"):
            self.assertEqual(self.files[entry][0], (self.profile / entry).read_bytes())
            if shutil.which("git"):
                result = subprocess.run(
                    ["git", "check-ignore", "-q", f"{self.profile_name}/{entry}"],
                    cwd=ROOT, capture_output=True, timeout=10, check=False,
                )
                self.assertEqual(result.returncode, 1, f"source entry is ignored: {entry}")

    def test_common_skills_and_local_rules_are_available(self) -> None:
        for skill in ("doctor", "research", "plan", "implement", "review", "init-openspec"):
            suffix = f"skills/harness-{skill}/SKILL.md"
            self.assertEqual(self.files[f".agents/{suffix}"][0], self.files[f".claude/{suffix}"][0])
        for rule in (self.profile / "rules").glob("*.md"):
            self.assertEqual(self.files[f".claude/rules/{rule.name}"][0], rule.read_bytes())
        for script in ("read-error-journal.sh", "append-error-journal.ps1", "close-error-journal.sh"):
            self.assertIn(f".harness/scripts/{script}", self.files)

    def test_distribution_has_no_business_files_or_local_machine_paths(self) -> None:
        for name, (data, _) in self.files.items():
            self.assertEqual(updater.owned("harness", name), name)
            self.assertFalse(name.endswith(".go") or Path(name).name in {"go.mod", "go.sum", "package.json"})
            for local_path in (str(ROOT), str(Path.home())):
                self.assertNotIn(local_path.encode(), data, name)
        self.assertFalse((self.profile / "project-templates").exists())

    @unittest.skipUnless(shutil.which("bash"), "Bash not installed; CLI discovery unverified")
    def test_command_discovers_profile_without_installing(self) -> None:
        env = {**os.environ, "PYTHONDONTWRITEBYTECODE": "1"}
        env.pop("HARNESS_CMD_NAME", None)
        for args in ([self.profile_name, "--help"], ["unknown-harness-for-test"]):
            with self.subTest(args=args):
                result = subprocess.run(
                    [shutil.which("bash"), "scripts/harness-init.sh", *args], cwd=ROOT,
                    env=env, capture_output=True, text=True, timeout=10, check=False,
                )
                self.assertEqual(result.returncode, 0 if args[-1] == "--help" else 1)
                self.assertIn(self.profile_name, result.stdout)

    def test_language_and_npm_rules_are_separate(self) -> None:
        self.assertNotIn(".harness/guides/typescript-runtime.md", self.files)
        release = self.files[".harness/guides/release-and-distribution.md"][0].decode()
        self.assertIn("npm", release)
        self.assertIn("预编译", release)
        self.assertIn("不默认要求", self.files["AGENTS.md"][0].decode())


class TypeScriptMCPDistributionTests(MCPDistributionTests):
    profile_name = "ts-mcp-harness"
    language_guide = "typescript-runtime.md"

    def test_language_and_npm_rules_are_separate(self) -> None:
        self.assertNotIn(".harness/guides/go-modern.md", self.files)
        skills = self.files[".harness/guides/skills-index.md"][0].decode()
        self.assertIn("senior-nodejs-engineer", skills)
        for go_skill in ("use-modern-go", "go-enterprise-quality", "go-testing"):
            self.assertNotIn(go_skill, skills)
        dependencies = self.files[".harness/guides/dependencies.md"][0].decode()
        self.assertIn("@modelcontextprotocol/server", dependencies)
        self.assertNotIn("github.com/gtkit/", dependencies)
        self.assertIn("npm", self.files[".harness/guides/release-and-distribution.md"][0].decode())


if __name__ == "__main__":
    unittest.main(verbosity=2)
