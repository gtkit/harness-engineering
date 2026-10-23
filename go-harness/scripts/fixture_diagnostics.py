"""Test-only process observations; never installed into production hook modules."""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import tempfile
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Callable


def write_json(path: Path, value: Any) -> None:
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def save_output(directory: Path, name: str, value: str | bytes | None) -> dict[str, Any]:
    data = value.encode("utf-8") if isinstance(value, str) else value or b""
    (directory / name).write_bytes(data)
    return {"path": name, "available": value is not None, "bytes": len(data),
            "representation": "utf-8 text" if isinstance(value, str) else "bytes"}


def record_process(directory: Path, kind: str, args: list[str], *,
                   details: dict[str, Any] | None = None,
                   runner: Callable[..., Any] = subprocess.run, **kwargs: Any) -> Any:
    """Return/re-raise the original result while persisting all observed output."""
    directory.mkdir(parents=True, exist_ok=True)
    record_dir = Path(tempfile.mkdtemp(prefix=kind + "-", dir=directory))
    record = {"schema_version": 1, "kind": kind, "argv": [os.fspath(arg) for arg in args],
              "cwd": os.fspath(kwargs.get("cwd") or Path.cwd()), "observer_pid": os.getpid(),
              "started_at": datetime.now(UTC).isoformat(), "timeout_seconds": kwargs.get("timeout"),
              "status": "running", "exit_code": None, "duration_seconds": None,
              "stderr_merged": kwargs.get("stderr") == subprocess.STDOUT,
              "details": details or {}, "stdin": save_output(record_dir, "stdin", kwargs.get("input"))}
    write_json(record_dir / "record.json", record)
    started = time.monotonic()
    stdout = stderr = None
    try:
        result = runner(args, **kwargs)
        stdout, stderr = result.stdout, result.stderr
        record.update(status="exited", exit_code=result.returncode)
        return result
    except BaseException as exc:
        stdout, stderr = getattr(exc, "stdout", None), getattr(exc, "stderr", None)
        status = "timeout" if isinstance(exc, subprocess.TimeoutExpired) else "os_error" if isinstance(exc, OSError) else "error"
        record.update(status=status, exit_code=getattr(exc, "returncode", None),
                      exception={"type": type(exc).__name__, "message": str(exc)})
        raise
    finally:
        record["duration_seconds"] = time.monotonic() - started
        record["stdout"] = save_output(record_dir, "stdout", stdout)
        record["stderr"] = save_output(record_dir, "stderr", stderr)
        write_json(record_dir / "record.json", record)


class SubprocessTrace:
    """A module-local proxy observing only the fixture's selected fake CLI."""

    def __init__(self, backend: Any, directory: str | Path, cli: str | Path):
        self.backend = backend
        self.directory = Path(directory)
        self.cli = Path(cli).resolve()

    def __getattr__(self, name: str) -> Any:
        return getattr(self.backend, name)

    def run(self, args: list[str], **kwargs: Any) -> Any:
        if isinstance(args, (list, tuple)) and args and Path(args[0]).resolve() == self.cli:
            return record_process(self.directory, "cli", args, runner=self.backend.run, **kwargs)
        return self.backend.run(args, **kwargs)


def retain_failure(directory: Path, destination: Path, test_id: str,
                   failures: list[str], snapshots: dict[str, Path]) -> Path:
    """Copy evidence before TemporaryDirectory cleanup; never overwrite a run."""
    destination.mkdir(parents=True, exist_ok=True)
    prefix = re.sub(r"[^A-Za-z0-9_.-]", "_", test_id)[-100:] + "-"
    retained = Path(tempfile.mkdtemp(prefix=prefix, dir=destination))
    if directory.exists():
        shutil.copytree(directory, retained / "processes")
    write_json(retained / "failure.json", {"test_id": test_id, "failures": failures})
    for name, source in snapshots.items():
        if source.is_file():
            shutil.copy2(source, retained / name)
    return retained.resolve()
