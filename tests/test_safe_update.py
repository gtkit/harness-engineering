from __future__ import annotations
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / ('safe_update.py' if (ROOT / 'safe_update.py').is_file() else 'scripts/safe_update.py')
spec = importlib.util.spec_from_file_location('updater', ENGINE)
u = importlib.util.module_from_spec(spec)
spec.loader.exec_module(u)
BLOCK = b'<!-- OPENSPEC-AUTO:START -->\nOpenSpec old rule\n<!-- OPENSPEC-AUTO:END -->\n'
TEXT = b'\n'.join(('line ' + str(n)).encode() for n in range(20)) + b'\n'

class SafeUpdateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.home = self.root / 'user-config'
        self.home.mkdir()
        patch = mock.patch.object(Path, 'home', return_value=self.home)
        patch.start(); self.addCleanup(patch.stop)
        self.project = self.root / 'project with spaces'; self.project.mkdir()
        self.h = self.root / 'harness-engineering'; self.h.mkdir()
        self.o = self.root / 'openspec-auto-bootstrap'; self.o.mkdir()
        self.write(self.o / 'VERSION', b'1.5.1\n')
        self.write(self.o / 'templates/repo/AGENTS.md', BLOCK)
        self.write(self.o / 'templates/repo/CLAUDE.md', BLOCK)
        self.write(self.o / 'templates/repo/.openspec-auto/tools/hook_common.py', TEXT)
        self.write(self.o / 'templates/repo/.openspec-auto/tools/other.py', b'old\n')
        self.write(self.o / 'templates/repo/.codex/hooks.json', u.json_bytes({'hooks': {'Stop': [{'hooks': [{'command': 'openspec-stop'}]}]}}))
        for name in ['AGENTS.md', 'CLAUDE.md']:
            self.write(self.h / 'go-harness' / name, b'# Harness\n\nold rule\n' + TEXT)
        prefix = 'ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; PY="$(command -v python3 || command -v python)"; "$PY" "$ROOT/.harness/hooks/'
        script = "printf '%s' '" + prefix + "'\"$1\"'\"'\n"
        script += "_harness_register_hook \"${cfg}\" \"${hook_python}\" SessionStart '.*' session_start.py 15\n"
        script += "_harness_register_hook \"${cfg}\" \"${hook_python}\" PreToolUse 'Bash|Write|Edit|MultiEdit|NotebookEdit' pre_tool_use.py 10\n"
        self.write(self.h / 'scripts/install-harness.sh', script.encode())
        self.write(self.h / 'go-harness/shared-guides.txt', b'common/guide.md\n')
        self.write(self.h / 'shared/guides/common/guide.md', TEXT)
        self.write(self.h / 'skills/harness-doctor/SKILL.md', b'---\nname: harness-doctor\n---\n')
        for name in ['session_start.py', 'pre_tool_use.py']:
            self.write(self.h / 'scripts/hooks' / name, b'# old hook\n')

    @staticmethod
    def write(path, content):
        path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(content)

    def seed(self, component):
        source, kind = (self.h, 'go-harness') if component == 'harness' else (self.o, None)
        snap = u.snapshot(component, source, kind)
        for rel, packed in snap['files'].items():
            value = u.unpacked(packed); path = self.project / rel
            if rel in ['AGENTS.md', 'CLAUDE.md'] and path.exists() and component == 'openspec':
                value = u.entry(path.read_bytes() + b'\n' + value[0], value[1])
            elif rel.endswith('.json') and path.exists():
                old, new = json.loads(path.read_bytes()), json.loads(value[0])
                for event, groups in new.get('hooks', {}).items():
                    old.setdefault('hooks', {}).setdefault(event, []).extend(groups)
                value = u.entry(u.json_bytes(old), value[1])
            self.write(path, value[0]); path.chmod(value[1])
        marker = '.harness/VERSION' if component == 'harness' else '.openspec-auto/version'
        body = b'harness: go-harness\nsource-commit: unknown\n' if component == 'harness' else b'1.5.1\n'
        self.write(self.project / marker, body)
        self.write(self.project / u.baseline_path(component), u.json_bytes(snap))
        (self.project / u.baseline_path(component)).chmod(0o600)

    def run_update(self, components=None, dry=False):
        components = components or [('openspec', self.o, None)]
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return u.update(self.project, components, dry)

    def tree(self):
        return {str(p.relative_to(self.project)): (p.read_bytes(), p.stat().st_mode & 0o777) for p in self.project.rglob('*') if p.is_file()}

    def test_uninstalled_components_and_missing_directory_are_untouched(self):
        before = self.tree()
        self.run_update([('harness', self.h, 'go-harness'), ('openspec', self.o, None)])
        self.assertEqual(before, self.tree()); self.assertFalse((self.home / '.config').exists())
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(u.update(self.project / 'absent', [('openspec', self.o, None)]), 0)
        self.assertFalse((self.project / 'absent').exists())

    def test_non_overlapping_customization_merges_and_is_idempotent(self):
        self.seed('openspec')
        local = self.project / '.openspec-auto/tools/hook_common.py'
        local.write_bytes(TEXT.replace(b'line 1\n', b'local one\n'))
        self.write(self.o / 'templates/repo/.openspec-auto/tools/hook_common.py', TEXT.replace(b'line 18\n', b'new eighteen\n'))
        self.run_update()
        self.assertIn(b'local one', local.read_bytes()); self.assertIn(b'new eighteen', local.read_bytes())
        after = self.tree(); self.run_update(); self.assertEqual(after, self.tree())
        manifests = list((self.home / '.config/openspec-auto/backups').rglob('manifest.json'))
        self.assertGreaterEqual(len(manifests), 1)
        self.assertIn(b'local one', (manifests[0].parent / 'files/.openspec-auto/tools/hook_common.py').read_bytes())

    def test_conflict_stops_all_writes_and_retains_three_versions(self):
        self.seed('openspec')
        self.write(self.project / '.openspec-auto/tools/other.py', b'local\n')
        self.write(self.o / 'templates/repo/.openspec-auto/tools/other.py', b'template\n')
        self.write(self.o / 'templates/repo/.openspec-auto/tools/new.py', b'new\n')
        before = self.tree()
        with self.assertRaises(u.UpdateError): self.run_update()
        self.assertEqual(before, self.tree())
        conflicts = list((self.home / '.config').rglob('other.py.*'))
        self.assertEqual({p.suffix for p in conflicts}, {'.base', '.local', '.template'})

    def test_combined_components_are_one_transaction(self):
        self.seed('harness'); self.seed('openspec')
        self.write(self.h / 'shared/guides/common/guide.md', b'new guide\n')
        self.write(self.o / 'templates/repo/.openspec-auto/tools/other.py', b'upstream\n')
        self.write(self.project / '.openspec-auto/tools/other.py', b'custom\n')
        before = self.tree()
        with self.assertRaises(u.UpdateError):
            self.run_update([('harness', self.h, 'go-harness'), ('openspec', self.o, None)])
        self.assertEqual(before, self.tree())

    def test_shared_root_rules_and_foreign_hooks_are_preserved(self):
        self.seed('harness'); self.seed('openspec')
        agent = self.project / 'AGENTS.md'; agent.write_bytes(agent.read_bytes() + b'\n## Project custom\nKeep layout.\n')
        config = self.project / '.codex/hooks.json'; value = json.loads(config.read_bytes())
        value['permissions'] = {'allow': ['custom-read']}; value['hooks']['Other'] = [{'hooks': [{'command': 'custom-hook'}]}]
        config.write_bytes(u.json_bytes(value))
        self.write(self.h / 'go-harness/AGENTS.md', (self.h / 'go-harness/AGENTS.md').read_bytes().replace(b'old rule', b'new rule'))
        self.write(self.o / 'templates/repo/AGENTS.md', BLOCK.replace(b'old rule', b'new workflow'))
        newconfig = json.loads((self.o / 'templates/repo/.codex/hooks.json').read_bytes()); newconfig['hooks']['NewEvent'] = []
        self.write(self.o / 'templates/repo/.codex/hooks.json', u.json_bytes(newconfig))
        self.run_update([('harness', self.h, 'go-harness'), ('openspec', self.o, None)])
        text = agent.read_bytes(); self.assertIn(b'new rule', text); self.assertIn(b'new workflow', text); self.assertIn(b'Keep layout.', text)
        self.assertEqual(text.count(b'OPENSPEC-AUTO:START'), 1)
        value = json.loads(config.read_bytes()); self.assertEqual(value['permissions']['allow'], ['custom-read']); self.assertIn('Other', value['hooks']); self.assertIn('SessionStart', value['hooks'])

    def test_custom_file_permissions_are_preserved(self):
        self.seed('openspec'); file = self.project / '.openspec-auto/tools/other.py'; file.chmod(0o600)
        self.write(self.o / 'templates/repo/.openspec-auto/tools/other.py', b'new\n'); self.run_update()
        self.assertEqual(file.stat().st_mode & 0o777, 0o600)

    def test_upstream_deletion_conflicts_with_local_edit(self):
        self.seed('openspec'); file = self.project / '.openspec-auto/tools/other.py'; file.write_bytes(b'custom\n')
        (self.o / 'templates/repo/.openspec-auto/tools/other.py').unlink(); before = self.tree()
        with self.assertRaises(u.UpdateError): self.run_update()
        self.assertEqual(before, self.tree())

    def test_clean_upstream_deletion_is_applied(self):
        self.seed('openspec'); (self.o / 'templates/repo/.openspec-auto/tools/other.py').unlink(); self.run_update()
        self.assertFalse((self.project / '.openspec-auto/tools/other.py').exists())

    def test_local_deletion_is_preserved_until_upstream_also_changes(self):
        self.seed('openspec'); file = self.project / '.openspec-auto/tools/other.py'; file.unlink(); self.run_update(); self.assertFalse(file.exists())
        self.write(self.o / 'templates/repo/.openspec-auto/tools/other.py', b'new\n'); before = self.tree()
        with self.assertRaises(u.UpdateError): self.run_update()
        self.assertEqual(before, self.tree())

    def test_dry_run_never_creates_backup_or_writes(self):
        self.seed('openspec'); self.write(self.o / 'templates/repo/.openspec-auto/tools/other.py', b'new\n'); before = self.tree()
        self.run_update(dry=True); self.assertEqual(before, self.tree()); self.assertFalse((self.home / '.config').exists())

    def test_unknown_or_corrupt_baseline_is_not_guessed(self):
        self.seed('openspec'); (self.project / '.openspec-auto/update-base.json').unlink()
        self.write(self.project / '.openspec-auto/version', b'9.9.9\n'); before = self.tree()
        with self.assertRaises(u.UpdateError): self.run_update()
        self.assertEqual(before, self.tree())
        self.write(self.project / '.openspec-auto/update-base.json', b'{broken'); before = self.tree()
        with self.assertRaises(u.UpdateError): self.run_update()
        self.assertEqual(before, self.tree())

    def test_known_pre_baseline_version_uses_pristine_archive(self):
        self.seed('openspec'); snap = json.loads((self.project / '.openspec-auto/update-base.json').read_bytes())
        (self.project / '.openspec-auto/update-base.json').unlink(); self.write(self.o / 'update-baselines.json', u.json_bytes({'1.5.1': snap}))
        self.write(self.project / '.openspec-auto/tools/other.py', b'project custom\n')
        self.write(self.o / 'VERSION', b'1.6.0\n'); self.run_update()
        self.assertEqual((self.project / '.openspec-auto/tools/other.py').read_bytes(), b'project custom\n')
        self.assertEqual((self.project / '.openspec-auto/version').read_bytes(), b'1.6.0\n')

    def test_symlink_and_existing_lock_stop_without_modification(self):
        self.seed('openspec'); file = self.project / '.openspec-auto/tools/other.py'; file.unlink(); outside = self.root / 'outside'; outside.write_bytes(b'outside'); file.symlink_to(outside)
        with self.assertRaises(u.UpdateError): self.run_update()
        self.assertEqual(outside.read_bytes(), b'outside'); file.unlink(); file.write_bytes(b'old\n')
        lock = self.project / '.openspec-auto/update.lock'; lock.write_text('existing owner')
        with self.assertRaises(u.UpdateError): self.run_update()
        self.assertEqual(lock.read_text(), 'existing owner')

    def test_write_error_rolls_back_original_files(self):
        self.seed('openspec'); self.write(self.o / 'VERSION', b'1.6.0\n'); self.write(self.o / 'templates/repo/.openspec-auto/tools/other.py', b'new\n'); before = self.tree(); real = u.atomic_write
        def fail_version(root, rel, value, created):
            if rel == '.openspec-auto/version' and value[0] == b'1.6.0\n': raise OSError('simulated disk error')
            return real(root, rel, value, created)
        with mock.patch.object(u, 'atomic_write', side_effect=fail_version), self.assertRaises(OSError): self.run_update()
        self.assertEqual(before, self.tree())

    def test_wrong_harness_kind_is_rejected(self):
        self.seed('harness'); before = self.tree()
        with self.assertRaises(u.UpdateError): self.run_update([('harness', self.h, 'go-pkg-harness')])
        self.assertEqual(before, self.tree())

    def test_hook_config_is_derived_from_the_actual_installer(self):
        self.seed('harness')
        config = self.project / '.codex/hooks.json'; value = json.loads(config.read_bytes()); value['permissions'] = {'allow': ['custom']}; config.write_bytes(u.json_bytes(value))
        installer = self.h / 'scripts/install-harness.sh'; installer.write_bytes(installer.read_bytes().replace(b'pre_tool_use.py 10', b'pre_tool_use.py 20'))
        self.run_update([('harness', self.h, 'go-harness')])
        value = json.loads(config.read_bytes()); self.assertEqual(value['permissions']['allow'], ['custom']); self.assertEqual(value['hooks']['PreToolUse'][0]['hooks'][0]['timeout'], 20)

    def test_historical_harness_baseline_and_dirty_template_are_detected(self):
        self.seed('harness')
        for args in [('init', '-q'), ('add', '.'), ('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'old template')]:
            subprocess.run(['git', *args], cwd=self.h, check=True, capture_output=True)
        revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=self.h).decode().strip()
        self.write(self.project / '.harness/VERSION', ('harness: go-harness\nsource-commit: ' + revision + '\n').encode())
        (self.project / '.harness/update-base.json').unlink()
        guide = self.project / '.harness/guides/guide.md'; guide.write_bytes(TEXT.replace(b'line 1\n', b'local one\n'))
        self.write(self.h / 'shared/guides/common/guide.md', TEXT.replace(b'line 18\n', b'new eighteen\n'))
        self.run_update([('harness', self.h, 'go-harness')])
        self.assertIn(b'local one', guide.read_bytes()); self.assertIn(b'new eighteen', guide.read_bytes())

    def public_command(self, component, *arguments):
        scripts = self.root / 'fake-bin'; scripts.mkdir(exist_ok=True)
        interpreter = scripts / 'python3'; interpreter.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n'); interpreter.chmod(0o755)
        runner_env = dict(os.environ); runner_env['PATH'] = str(scripts) + os.pathsep + os.environ['PATH']
        if component == 'openspec':
            wrapper = ROOT / 'openspec-auto'
            if not wrapper.is_file(): wrapper = ROOT.parent / 'openspec-auto-bootstrap/openspec-auto'
            shutil.copy2(wrapper, self.o / 'openspec-auto')
            command = ['/bin/bash', str(self.o / 'openspec-auto'), *arguments]
        else:
            wrapper = ROOT / 'scripts/harness-init.sh'
            if not wrapper.is_file(): wrapper = ROOT.parent / 'harness-engineering/scripts/harness-init.sh'
            if not wrapper.is_file(): self.skipTest('standalone checkout has no harness CLI')
            shutil.copy2(wrapper, self.h / 'scripts/harness-init.sh')
            self.write(self.h / 'go-harness/setup.sh', b'#!/bin/bash\nexit 97\n')
            command = ['/bin/bash', str(self.h / 'scripts/harness-init.sh'), 'go-harness', *arguments]
        return subprocess.run(command, env=runner_env, capture_output=True, text=True)

    def test_public_commands_route_existing_installs_to_update(self):
        self.seed('harness'); self.seed('openspec'); before = self.tree()
        for component, arguments in [('harness', (str(self.project),)), ('openspec', ('install', str(self.project)))]:
            with self.subTest(component=component):
                proc = self.public_command(component, *arguments)
                self.assertEqual(proc.returncode, 0, proc.stderr); self.assertIn('update', proc.stdout); self.assertIn('--component', proc.stdout)
        self.assertEqual(before, self.tree())

    def test_public_commands_reject_force_for_existing_installs(self):
        self.seed('harness'); self.seed('openspec'); before = self.tree()
        for component, arguments in [('harness', (str(self.project), '--force')), ('openspec', ('install', '--force', str(self.project)))]:
            with self.subTest(component=component):
                proc = self.public_command(component, *arguments)
                self.assertNotEqual(proc.returncode, 0); self.assertIn('update', proc.stderr)
        self.assertEqual(before, self.tree())

    def test_baseline_cannot_claim_business_files(self):
        self.seed('openspec'); self.write(self.project / 'main.go', b'package main\n')
        file = self.project / '.openspec-auto/update-base.json'; value = json.loads(file.read_bytes()); value['files']['main.go'] = u.packed(u.entry(b'package main\n')); file.write_bytes(u.json_bytes(value)); before = self.tree()
        with self.assertRaises(u.UpdateError): self.run_update()
        self.assertEqual(before, self.tree())

    def test_upstream_cannot_install_another_component(self):
        self.seed('openspec'); self.write(self.o / 'templates/repo/.harness/guides/new.md', b'foreign component'); before = self.tree()
        with self.assertRaises(u.UpdateError): self.run_update()
        self.assertEqual(before, self.tree()); self.assertFalse((self.project / '.harness').exists())

    def test_historical_install_before_hooks_preserves_foreign_hook_groups(self):
        old_script = self.h / 'scripts/install-harness.sh'; current_script = old_script.read_bytes()
        old_script.write_bytes(b'# old installer before hooks\n')
        for name in ['session_start.py', 'pre_tool_use.py']: (self.h / 'scripts/hooks' / name).unlink()
        for args in [('init', '-q'), ('add', '.'), ('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'before hooks')]: subprocess.run(['git', *args], cwd=self.h, check=True, capture_output=True)
        revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=self.h).decode().strip()
        for rel, value in u.templates('harness', self.h, 'go-harness', revision).items(): self.write(self.project / rel, value[0])
        self.write(self.project / '.harness/VERSION', ('harness: go-harness\nsource-commit: ' + revision + '\n').encode())
        cfg = self.project / '.codex/hooks.json'; self.write(cfg, u.json_bytes({'hooks': {'PreToolUse': [{'matcher': 'Edit', 'hooks': [{'command': 'foreign guard'}]}]}, 'permissions': {'allow': ['custom']}})); cfg.chmod(0o600)
        old_script.write_bytes(current_script)
        for name in ['session_start.py', 'pre_tool_use.py']: self.write(self.h / 'scripts/hooks' / name, b'# new hook\n')
        self.run_update([('harness', self.h, 'go-harness')])
        result = json.loads(cfg.read_bytes()); self.assertEqual(result['permissions']['allow'], ['custom']); self.assertEqual(len(result['hooks']['PreToolUse']), 2); self.assertEqual(cfg.stat().st_mode & 0o777, 0o600)

    def test_public_help_never_executes_the_updater(self):
        self.seed('harness'); self.seed('openspec'); before = self.tree()
        for component, arguments in [('harness', ('update', '--help')), ('openspec', ('update', '--help')), ('openspec', ('install', '--help', str(self.project)))]:
            with self.subTest(component=component, arguments=arguments):
                proc = self.public_command(component, *arguments); self.assertEqual(proc.returncode, 0, proc.stderr); self.assertNotIn('safe_update.py', proc.stdout)
        self.assertEqual(before, self.tree())

    def test_public_update_cannot_override_internal_component_or_source(self):
        self.seed('harness'); self.seed('openspec'); before = self.tree()
        for component in ('harness', 'openspec'):
            proc = self.public_command(component, 'update', str(self.project), '--component', 'other')
            self.assertNotEqual(proc.returncode, 0); self.assertNotIn('safe_update.py', proc.stdout)
        self.assertEqual(before, self.tree())

    def test_cli_preview_handles_spaces_and_uninstalled_project(self):
        proc = subprocess.run([sys.executable, str(ENGINE), 'update', '--component', 'openspec', '--source', str(self.o), '--dry-run', str(self.project)], capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr); self.assertIn('跳过未安装', proc.stdout)

if __name__ == '__main__': unittest.main()
