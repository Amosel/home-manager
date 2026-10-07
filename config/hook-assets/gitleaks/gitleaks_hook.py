"""Managed Codex SessionStart secret scan; no third-party Python dependencies."""
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import time

MARKER = "Skill Manager: Gitleaks startup scan"
EXCLUDED_ROOT_DIRS = {
    ".git", ".astro", ".cache", ".playwright-mcp", ".vercel",
    ".wrangler", "dist", "node_modules", "output",
}


def codex_home():
    return Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))).expanduser()


def paths(home):
    base = home / "managed-hooks" / "skill-manager-gitleaks"
    return home / "hooks.json", base / "scan.py", base / "receipt.json"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_hooks(path):
    data = json.loads(path.read_text()) if path.exists() else {}
    if not isinstance(data, dict) or not isinstance(data.get("hooks", {}), dict):
        raise ValueError("Invalid hooks.json object")
    groups = data.get("hooks", {}).get("SessionStart", [])
    if not isinstance(groups, list) or any(not isinstance(g, dict) for g in groups):
        raise ValueError("Invalid SessionStart groups")
    if any(not isinstance(g.get("hooks", []), list) or
           any(not isinstance(h, dict) for h in g.get("hooks", [])) for g in groups):
        raise ValueError("Invalid SessionStart handlers")
    return data


def owned(group):
    return any(isinstance(h, dict) and h.get("statusMessage") == MARKER
               for h in group.get("hooks", []))


def atomic_write(path, content):
    if path.is_symlink():
        raise ValueError(f"Refusing to replace symlink: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(dir=path.parent, prefix=".gitleaks-")
    try:
        with os.fdopen(fd, "w") as handle:
            handle.write(content)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def validate(home, required=False):
    state_path = home / 'managed-hooks/skill-manager/state.json'
    if state_path.exists() and json.loads(state_path.read_text()):
        import hook_manager
        state=json.loads(state_path.read_text())
        return hook_manager.validate(Path(state['config']),home)
    hooks_path, script, receipt_path = paths(home)
    if not receipt_path.exists():
        # An orphan hook is drift, not an unconfigured installation.
        groups = read_hooks(hooks_path).get("hooks", {}).get("SessionStart", [])
        if required or script.exists() or any(owned(g) for g in groups):
            raise ValueError("Gitleaks hook receipt missing; run gitleaks-hook --execute")
        return {"status": "not_configured"}
    receipt = json.loads(receipt_path.read_text())
    groups = read_hooks(hooks_path).get("hooks", {}).get("SessionStart", [])
    matches = [g for g in groups if owned(g)]
    if matches != [receipt["group"]]:
        raise ValueError("Gitleaks hook missing or changed; run gitleaks-hook --execute")
    if not script.is_file() or digest(script) != receipt["sha256"]:
        raise ValueError("Gitleaks hook script missing or changed; run gitleaks-hook --execute")
    for executable in receipt["executables"]:
        if not Path(executable).is_file() or not os.access(executable, os.X_OK):
            raise ValueError(f"Gitleaks hook executable unavailable: {executable}")
    return {"status": "valid", "trust": "not_verified", "hooks_file": str(hooks_path)}


def install(home, execute=False):
    import hook_manager
    return hook_manager.command('apply',hook_manager.DEFAULT_CONFIG,home,execute)


def scan(cwd, binary):
    """Return only bounded finding metadata, never scanner logs or secret values."""
    if not cwd.is_dir():
        raise ValueError("Session directory unavailable")
    # Gitleaks' directory mode does not honor .gitignore. Scan each root entry
    # separately so known build, dependency, and media caches can be skipped.
    # Keep leading-dash filenames from being interpreted as scanner options.
    targets = [f"./{entry.name}" for entry in sorted(cwd.iterdir())
               if not (entry.is_dir() and entry.name in EXCLUDED_ROOT_DIRS)]
    with tempfile.TemporaryDirectory(prefix="gitleaks-hook-") as temp:
        deadline = time.monotonic() + 55
        found = []
        finding_count = 0
        for index, target in enumerate(targets):
            remaining = deadline - time.monotonic()
            if remaining <= 1:
                raise subprocess.TimeoutExpired(binary, 55)
            report = Path(temp) / f"report-{index}.json"
            scan_seconds = max(1, int(remaining) - 1)
            command = [binary, "dir", target, "--redact=100", "--no-banner", "--no-color",
                       "--exit-code", "10", "--timeout", str(scan_seconds),
                       "--report-format", "json", "--report-path", str(report)]
            if (not os.environ.get("GITLEAKS_CONFIG") and
                    not os.environ.get("GITLEAKS_CONFIG_TOML") and
                    (cwd / ".gitleaks.toml").is_file()):
                command.extend(["--config", str(cwd / ".gitleaks.toml")])
            completed = subprocess.run(command, cwd=cwd, stdout=subprocess.DEVNULL,
                                       stderr=subprocess.DEVNULL, timeout=remaining)
            if completed.returncode not in (0, 10):
                raise ValueError(f"Scanner failed (exit {completed.returncode}); scan unverified")
            findings = json.loads(report.read_text())
            if not isinstance(findings, list):
                raise ValueError("Invalid Gitleaks report")
            if completed.returncode == 10 and not findings:
                raise ValueError("Gitleaks reported findings without details")
            finding_count += len(findings)
            found.extend(findings[:max(0, 20 - len(found))])
        return {"status": "findings" if finding_count else "clean", "count": finding_count,
                "findings": [{k: item.get(k) for k in ("File", "StartLine", "RuleID")}
                             for item in found]}


def hook_main(binary):
    try:
        event = json.load(sys.stdin)
        cwd = Path(event["cwd"])
        if not cwd.is_absolute():
            raise ValueError("Session cwd must be absolute")
        result = scan(cwd, binary)
        message = "Gitleaks startup scan: " + json.dumps(result)
    except (OSError, ValueError, KeyError, TypeError, subprocess.TimeoutExpired):
        message = "Gitleaks startup scan failed; project secret scan unverified. Check scanner installation, timeout, and hook configuration."
    print(json.dumps({"systemMessage": message,
                      "hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": message}}))


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] != "--hook":
        raise SystemExit("Use skill_manager.py gitleaks-hook to configure this hook")
    hook_main(sys.argv[2])
