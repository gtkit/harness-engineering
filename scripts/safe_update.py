#!/usr/bin/env python3
"""Transactional template updates. Mirrored in openspec-auto-bootstrap/safe_update.py."""
from __future__ import annotations

import argparse
import base64
from contextlib import ExitStack, contextmanager, nullcontext
import datetime as dt
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tempfile
import uuid

BLOCK = re.compile(rb'<!-- OPENSPEC-AUTO:START -->.*?<!-- OPENSPEC-AUTO:END -->', re.S)
MISSING = object()


class UpdateError(Exception):
    pass


def relative(name):
    p = PurePosixPath(name)
    if p.is_absolute() or not p.parts or '..' in p.parts or '\\' in name:
        raise UpdateError('不安全的托管路径: ' + name)
    return str(p)


def owned(component, name):
    name = relative(name)
    if name in {'AGENTS.md', 'CLAUDE.md', '.claude/settings.json', '.codex/hooks.json'}:
        return name
    if component == 'harness':
        prefixes = ('.harness/guides/', '.harness/scripts/', '.harness/hooks/', '.agents/skills/harness-', '.claude/skills/harness-')
        valid = name.startswith(prefixes) or name.startswith('.claude/rules/harness-')
    else:
        prefixes = ('.openspec-auto/hooks/', '.openspec-auto/tools/', '.agents/skills/openspec-auto/', '.claude/skills/openspec-auto/', 'tools/openspec/', '.claude/hooks/openspec_', '.codex/hooks/openspec_')
        valid = name.startswith(prefixes) or name in {'.codex/config.toml.append', '.codex/prompts/openspec-auto.md'}
    if not valid:
        raise UpdateError('基线或模板越过组件管理范围: ' + name)
    return name


def entry(data, mode=0o644):
    return (data, mode)


def packed(value):
    if value is None:
        return None
    return {'content': base64.b64encode(value[0]).decode(), 'mode': value[1],
            'sha256': hashlib.sha256(value[0]).hexdigest()}


def unpacked(value):
    if value is None:
        return None
    data = base64.b64decode(value['content'], validate=True)
    if hashlib.sha256(data).hexdigest() != value['sha256']:
        raise UpdateError('基线校验失败')
    mode = value['mode']
    if not isinstance(mode, int) or mode < 0 or mode > 0o777:
        raise UpdateError('基线权限无效')
    return entry(data, mode)


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + '\n').encode()


def git(source, *args):
    try:
        result = subprocess.run(['git', '-C', str(source), *args], capture_output=True)
    except OSError as exc:
        raise UpdateError('无法运行 Git: ' + str(exc)) from exc
    if result.returncode:
        raise UpdateError('无法读取模板历史: ' + ' '.join(args[:2]))
    return result.stdout


class Source:
    def __init__(self, root, revision=None):
        self.root, self.revision = Path(root), revision
        self.modes = {}
        if revision:
            if not re.fullmatch(r'[0-9a-f]{7,40}|v?\d+\.\d+\.\d+(?:[-.][\w.-]+)?', revision):
                raise UpdateError('无效的历史版本: ' + revision)
            for record in git(root, 'ls-tree', '-rz', revision).split(b'\0'):
                if record:
                    meta, path = record.split(b'\t', 1)
                    mode, kind, _ = meta.split()
                    if kind == b'blob' and mode in (b'100644', b'100755'):
                        self.modes[path.decode()] = 0o755 if mode == b'100755' else 0o644
        else:
            for current, dirs, files in os.walk(root, followlinks=False):
                dirs[:] = [d for d in dirs if d not in {'.git', '__pycache__', 'node_modules', '.venv'}]
                for name in files:
                    p = Path(current) / name
                    if not p.is_symlink() and name != '.DS_Store' and p.suffix != '.pyc':
                        self.modes[p.relative_to(root).as_posix()] = p.stat().st_mode & 0o777

    def read(self, name):
        name = relative(name)
        if name not in self.modes:
            raise UpdateError('模板文件不存在: ' + name)
        return entry(git(self.root, 'show', self.revision + ':' + name) if self.revision
                     else (self.root / name).read_bytes(), self.modes[name])


def harness_hooks(tree):
    script = tree.read('scripts/install-harness.sh')[0].decode()
    command_parts = re.search(r"printf '%s' '([^'\n]+)'\"\$1\"'([^'\n]*)'", script)
    registrations = re.findall(r"_harness_register_hook\s+\"\$\{cfg\}\"\s+\"\$\{hook_python\}\"\s+(\w+)\s+'([^']*)'\s+(\S+)\s+(\d+)", script)
    if tree.revision and '_harness_register_hook' not in script:
        return None
    if not command_parts or not registrations:
        raise UpdateError('无法识别 harness hook 模板，停止而不猜测配置')
    hooks = {}
    for event, matcher, name, timeout in registrations:
        command = command_parts[1] + name + command_parts[2]
        hooks.setdefault(event, []).append({'matcher': matcher, 'hooks': [{'type': 'command', 'command': command, 'timeout': int(timeout)}]})
    return entry(json_bytes({'hooks': hooks}))


def templates(component, source, kind=None, revision=None):
    tree = Source(source, revision)
    files = {}
    if component == 'openspec':
        for path in tree.modes:
            if path.startswith('templates/repo/'):
                rel = path[len('templates/repo/'):]
                value = tree.read(path)
                if rel.startswith('.openspec-auto/hooks/') or rel in {
                    '.openspec-auto/tools/env.sh', '.openspec-auto/tools/healthcheck.sh',
                    '.openspec-auto/tools/sync_templates.sh'}:
                    value = entry(value[0], 0o755)
                files[rel] = value
    else:
        if not kind or kind + '/AGENTS.md' not in tree.modes:
            raise UpdateError('未知 harness 类型: ' + str(kind))
        manifest = kind + '/shared-guides.txt'
        if manifest in tree.modes:
            for line in tree.read(manifest)[0].decode().splitlines():
                rel = line.split('#', 1)[0].strip()
                if rel and Path(rel).name != 'error-journal-template.md':
                    files['.harness/guides/' + Path(rel).name] = tree.read('shared/guides/' + rel)
        for path in tree.modes:
            if path.startswith(kind + '/guides/') and path.endswith('.md') and Path(path).name != 'error-journal-template.md':
                files['.harness/guides/' + Path(path).name] = tree.read(path)
            for prefix, target in (
                ('skills/', '.agents/skills/'), ('skills/', '.claude/skills/'),
                ('scripts/error-journal/', '.harness/scripts/'), (kind + '/rules/', '.claude/rules/'),
            ):
                if path.startswith(prefix):
                    files[target + path[len(prefix):]] = tree.read(path)
        for name in ('AGENTS.md', 'CLAUDE.md'):
            files[name] = tree.read(kind + '/' + name)
        for name in ('session_start.py', 'pre_tool_use.py'):
            if 'scripts/hooks/' + name in tree.modes or not revision:
                files['.harness/hooks/' + name] = tree.read('scripts/hooks/' + name)
        config = harness_hooks(tree)
        if config is not None:
            for name in ('.claude/settings.json', '.codex/hooks.json'):
                files[name] = config
    for name in files:
        owned(component, name)
    return files


def project_file(root, rel):
    target = root / relative(rel)
    for p in (target, *target.parents):
        if p == root:
            break
        if p.is_symlink():
            raise UpdateError('拒绝跟随项目内的符号链接: ' + rel)
    if target.exists() and not target.is_file():
        raise UpdateError('托管文件路径不是普通文件: ' + rel)
    return entry(target.read_bytes(), target.stat().st_mode & 0o777) if target.exists() else None


def project_parts(value, component):
    if value is None:
        return None
    data, mode = value
    blocks = BLOCK.findall(data)
    if data.count(b'<!-- OPENSPEC-AUTO:START -->') != len(blocks) or len(blocks) > 1:
        raise UpdateError('OpenSpec 托管块损坏或重复')
    part = (blocks[0] if blocks else b'') if component == 'openspec' else BLOCK.sub(b'', data).strip() + b'\n'
    return entry(part, mode)


def combine_root(original, merged, component):
    if merged is None:
        return None
    if original is not None and project_parts(original, component)[0] == merged[0]:
        return entry(original[0], merged[1])
    old = original[0] if original else b''
    if component == 'openspec':
        data = BLOCK.sub(lambda _: merged[0], old) if BLOCK.search(old) else old.rstrip() + (b'\n\n' + merged[0] + b'\n' if merged[0] else b'')
    else:
        blocks = BLOCK.findall(old)
        data = merged[0].rstrip() + (b'\n\n' + blocks[0] if blocks else b'') + b'\n'
    return entry(data, merged[1])


def snapshot(component, source, kind=None):
    files = templates(component, source, kind)
    try:
        revision = git(source, 'rev-parse', 'HEAD').decode().strip()
    except UpdateError:
        revision = 'unknown'
    if component == 'openspec':
        version = (Path(source) / 'VERSION').read_text().strip()
    else:
        version = revision[:12]
    result = {'schema': 1, 'component': component, 'kind': kind, 'version': version,
              'revision': revision, 'files': {p: packed(v) for p, v in sorted(files.items())}}
    if component == 'harness':
        result['source_path'] = str(Path(source).resolve())
        try:
            result['tag'] = git(source, 'describe', '--tags', '--abbrev=0').decode().strip()
        except UpdateError:
            result['tag'] = None
    return result


def baseline_path(component):
    return ('.harness' if component == 'harness' else '.openspec-auto') + '/update-base.json'


def baseline(component, root, source, kind):
    saved = project_file(root, baseline_path(component))
    if saved:
        data = json.loads(saved[0])
        if data.get('schema') != 1 or data.get('component') != component or data.get('kind') != kind:
            raise UpdateError('更新基线类型不匹配')
        return {owned(component, p): unpacked(v) for p, v in data['files'].items()}
    if component == 'harness':
        text = project_file(root, '.harness/VERSION')[0].decode()
        match = re.search(r'^source-commit:\s*(\S+)', text, re.M)
        if not match:
            raise UpdateError('旧安装没有 source-commit，无法推断可信基线')
        return templates(component, source, kind, match[1])
    version = project_file(root, '.openspec-auto/version')[0].decode().strip()
    archive = Path(source) / 'update-baselines.json'
    if archive.is_file():
        versions = json.loads(archive.read_text())
        if version in versions:
            return {owned(component, p): unpacked(v) for p, v in versions[version]['files'].items()}
    return templates(component, source, kind, 'v' + version)


def merge_bytes(base, local, latest):
    if local == latest or latest == base:
        return local
    if local == base:
        return latest
    if base is None or local is None or latest is None:
        raise UpdateError('新增文件碰撞或删除/修改冲突')
    with tempfile.TemporaryDirectory(prefix='agent-template-merge-') as temp:
        paths = [Path(temp) / name for name in ('local', 'base', 'template')]
        for p, data in zip(paths, (local, base, latest)):
            p.write_bytes(data)
        result = subprocess.run(['git', 'merge-file', '-p', '--diff3', '-L', 'local', '-L', 'base', '-L', 'template', *map(str, paths)], capture_output=True)
        if result.returncode:
            raise UpdateError('内容冲突')
        return result.stdout


def merge_json(base, local, latest):
    def walk(b, l, n):
        if l == n or n == b:
            return l
        if l == b:
            return n
        if b is MISSING and isinstance(l, dict) and isinstance(n, dict):
            b = {}
        if all(isinstance(v, dict) for v in (b, l, n)):
            result = {}
            for key in sorted(b.keys() | l.keys() | n.keys()):
                value = walk(b.get(key, MISSING), l.get(key, MISSING), n.get(key, MISSING))
                if value is not MISSING:
                    result[key] = value
            return result
        if b is MISSING and isinstance(l, list) and isinstance(n, list):
            def commands(group):
                if not isinstance(group, dict) or not isinstance(group.get('hooks'), list) or not group['hooks']:
                    raise UpdateError('没有基线的 JSON 列表不能猜测合并')
                result = set()
                for hook in group['hooks']:
                    if not isinstance(hook, dict) or not isinstance(hook.get('command'), str):
                        raise UpdateError('没有基线的 hook 配置不能猜测合并')
                    result.add(hook['command'])
                return result
            combined = list(l)
            existing = set().union(*(commands(group) for group in combined))
            for group in n:
                ids = commands(group)
                if group in combined:
                    continue
                if existing & ids:
                    raise UpdateError('新增 hook 与本地同名命令配置冲突')
                combined.append(group)
                existing |= ids
            return combined
        if any(v is MISSING for v in (b, l, n)):
            raise UpdateError('JSON 字段冲突')
        return json.loads(merge_bytes(json_bytes(b), json_bytes(l), json_bytes(n)))
    return json_bytes(walk(json.loads(base), json.loads(local), json.loads(latest)))


def merged_entry(base, local, latest, rel):
    b, l, n = (v[0] if v is not None else None for v in (base, local, latest))
    if rel.endswith('.json') and l is not None and n is not None and l != n and l != b and n != b:
        body = merge_json(b if b is not None else b'{}', l, n)
    else:
        body = merge_bytes(b, l, n)
    if body is None:
        return None
    bm, lm, nm = (v[1] if v is not None else None for v in (base, local, latest))
    if base is None and local is not None:
        mode = lm
    elif lm == nm or nm == bm:
        mode = lm
    elif lm == bm:
        mode = nm
    else:
        raise UpdateError('文件权限冲突')
    if mode is None:
        mode = latest[1]
    return entry(body, mode)


@contextmanager
def locked(root, components):
    paths = []
    try:
        for component in sorted(components):
            rel = ('.harness' if component == 'harness' else '.openspec-auto') + '/update.lock'
            project_file(root, rel)
            path = root / rel
            try:
                fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
            except FileExistsError:
                raise UpdateError('已有更新锁；确认没有更新进程后检查: ' + str(path))
            paths.append(path)
            with os.fdopen(fd, 'w') as stream:
                json.dump({'pid': os.getpid()}, stream)
        yield
    finally:
        for path in reversed(paths):
            path.unlink()


def atomic_write(root, rel, value, created):
    target = root / rel
    if value is None:
        target.unlink(missing_ok=True)
        return
    missing = []
    p = target.parent
    while not p.exists():
        missing.append(p)
        p = p.parent
    for p in reversed(missing):
        p.mkdir()
        created.append(p)
    with tempfile.NamedTemporaryFile(dir=target.parent, prefix='.agent-update-', delete=False) as stream:
        temporary = Path(stream.name)
        stream.write(value[0])
    try:
        temporary.chmod(value[1])
        os.replace(temporary, target)
    finally:
        temporary.unlink(missing_ok=True)


def version_entry(root, current, component, changed):
    if component == 'openspec':
        return '.openspec-auto/version', entry((current['version'] + '\n').encode())
    rel = '.harness/VERSION'
    old = project_file(root, rel)
    text = old[0].decode()
    fields = {'source-commit': current['version'], 'source-path': current['source_path'], 'source-tag': current['tag']}
    prior = dict(re.findall(r'^(source-commit|source-path|source-tag):\s*([^\n]+)', text, re.M))
    if not changed and all(prior.get(k) == v for k, v in fields.items()):
        return rel, old
    fields.update({'installed-at': dt.datetime.now().astimezone().isoformat(timespec='seconds'), 'installer': 'safe-update'})
    for key, value in fields.items():
        if value is None:
            text = re.sub(r'^' + key + r':[^\n]*\n?', '', text, flags=re.M)
        elif re.search(r'^' + key + ':', text, re.M):
            text = re.sub(r'^' + key + ':.*$', lambda _: key + ': ' + value, text, flags=re.M)
        else:
            text += key + ': ' + value + '\n'
    return rel, entry(text.encode(), old[1])


def update(root, components, dry_run=False):
    if not root.is_dir():
        print('跳过：目录不存在，未安装任何组件。')
        return 0
    selected = []
    for component, source, kind in components:
        marker = '.harness/VERSION' if component == 'harness' else '.openspec-auto/version'
        value = project_file(root, marker)
        if value is None:
            print('跳过未安装组件: ' + component)
            continue
        if component == 'harness':
            match = re.search(r'^harness:\s*(\S+)', value[0].decode(), re.M)
            if not match or match[1] != kind:
                raise UpdateError('harness 类型不匹配；请使用 .harness/VERSION 记录的命令')
        if not Path(source).is_dir():
            raise UpdateError('找不到已安装组件的模板源: ' + str(source))
        selected.append((component, Path(source), kind))
    if not selected:
        return 0
    with (nullcontext() if dry_run else locked(root, [c[0] for c in selected])):
        currents = {c: snapshot(c, source, kind) for c, source, kind in selected}
        originals, working, conflicts = {}, {}, []
        bases = {}
        for c, source, kind in selected:
            try:
                bases[c] = baseline(c, root, source, kind)
            except (UpdateError, ValueError, KeyError) as exc:
                bases[c] = None
                conflicts.append((c, 'update-base.json', None, None, None, str(exc)))
            names = set(currents[c]['files']) | set(bases[c] or {}) | {baseline_path(c), '.harness/VERSION' if c == 'harness' else '.openspec-auto/version'}
            for rel in names:
                if rel not in originals:
                    originals[rel] = project_file(root, rel)
                    working[rel] = originals[rel]
        # Backups precede merge and any project writes. They live outside the project.
        backup = None
        if not dry_run:
            stamp = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '.' + uuid.uuid4().hex[:8]
            namespace = 'harness-engineering' if any(c[0] == 'harness' for c in selected) else 'openspec-auto'
            backup = Path.home() / '.config' / namespace / 'backups' / stamp / root.name
            backup.mkdir(parents=True, mode=0o700)
            for rel, value in originals.items():
                if value is not None:
                    target = backup / 'files' / rel
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(value[0])
                    target.chmod(value[1])
                    if target.read_bytes() != value[0] or target.stat().st_mode & 0o777 != value[1]:
                        raise UpdateError('备份校验失败: ' + str(target))
            (backup / 'manifest.json').write_bytes(json_bytes({'project': str(root), 'files': {p: packed(v) for p, v in originals.items()}}))
            print('备份: ' + str(backup))
        for c, source, kind in selected:
            if bases[c] is None:
                continue
            base, latest = bases[c], {p: unpacked(v) for p, v in currents[c]['files'].items()}
            own_changed = False
            for rel in sorted(base.keys() | latest.keys()):
                b, l, n = base.get(rel), working.get(rel), latest.get(rel)
                is_root = rel in ('AGENTS.md', 'CLAUDE.md')
                if is_root:
                    b, l, n = (project_parts(v, c) for v in (b, l, n))
                    # Repair the old installer case: a root file containing only the other component's block.
                    if c == 'harness' and l and not l[0].strip() and originals.get(rel) and BLOCK.search(originals[rel][0]):
                        l = b
                try:
                    merged = merged_entry(b, l, n, rel)
                    if is_root:
                        merged = combine_root(working.get(rel), merged, c)
                    if merged != working.get(rel):
                        own_changed = True
                    working[rel] = merged
                except UpdateError as exc:
                    conflicts.append((c, rel, b, l, n, str(exc)))
            working[baseline_path(c)] = entry(json_bytes(currents[c]), 0o600)
            rel, value = version_entry(root, currents[c], c, own_changed)
            working[rel] = value
        if conflicts:
            for c, rel, b, l, n, reason in conflicts:
                print('冲突: ' + c + '/' + rel + ' — ' + reason, file=sys.stderr)
                if backup:
                    for label, value in (('base', b), ('local', l), ('template', n)):
                        if value is not None:
                            dest = backup / 'conflicts' / c / (rel + '.' + label)
                            dest.parent.mkdir(parents=True, exist_ok=True)
                            dest.write_bytes(value[0])
            raise UpdateError('已停止，项目文件未改动。对照备份中的 base/local/template 合并本地文件后重试；缺少基线时请恢复可信版本的 update-base.json，勿用强制覆盖代替合并。')
        changes = {p: v for p, v in working.items() if v != originals.get(p)}
        if dry_run:
            print('预览：' + str(len(changes)) + ' 个文件将更新；未写项目或创建备份。')
            for p in sorted(changes):
                print('  ' + p)
            return 0
        if not changes:
            print('已是最新；本地定制已保留。')
            return 0
        for rel, before in originals.items():
            if project_file(root, rel) != before:
                raise UpdateError('备份后文件发生变化，停止更新: ' + rel)
        applied, created = [], []
        try:
            for rel, after in sorted(changes.items()):
                if project_file(root, rel) != originals.get(rel):
                    raise UpdateError('写入前文件发生变化: ' + rel)
                atomic_write(root, rel, after, created)
                applied.append(rel)
                if project_file(root, rel) != after:
                    raise UpdateError('写入后校验失败: ' + rel)
        except BaseException:
            for rel in reversed(applied):
                if project_file(root, rel) != changes[rel]:
                    raise UpdateError('回滚遇到并发修改，请从备份恢复: ' + rel)
                atomic_write(root, rel, originals.get(rel), [])
            for directory in reversed(created):
                try:
                    directory.rmdir()
                except OSError:
                    pass
            raise
        (backup / 'result.json').write_bytes(json_bytes({'updated': sorted(changes), 'status': 'complete'}))
        print('安全更新完成: ' + str(len(changes)) + ' 个文件；项目定制已合并。')
        return 0


def main():
    if sys.version_info < (3, 10):
        raise UpdateError('安全更新需要 Python 3.10+')
    parser = argparse.ArgumentParser(description='只更新已安装组件：自动备份、三方合并；冲突时不写项目。')
    parser.add_argument('action', choices=['update', 'record'])
    parser.add_argument('project', nargs='?', default='.')
    parser.add_argument('--component', choices=['harness', 'openspec'], required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--kind')
    parser.add_argument('--openspec-source')
    parser.add_argument('--no-openspec', action='store_true')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    root = Path(args.project).resolve()
    if args.action == 'record':
        marker = '.harness/VERSION' if args.component == 'harness' else '.openspec-auto/version'
        if project_file(root, marker) is None:
            raise UpdateError('不能为未安装组件记录基线')
        current = snapshot(args.component, args.source, args.kind)
        atomic_write(root, baseline_path(args.component), entry(json_bytes(current), 0o600), [])
        return 0
    components = [(args.component, args.source, args.kind)]
    if args.component == 'harness' and not args.no_openspec:
        source = args.openspec_source or str(Path(args.source).parent / 'openspec-auto-bootstrap')
        components.append(('openspec', source, None))
    return update(root, components, args.dry_run)


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (UpdateError, OSError, ValueError, KeyError) as exc:
        print('安全更新失败: ' + str(exc), file=sys.stderr)
        raise SystemExit(1)
