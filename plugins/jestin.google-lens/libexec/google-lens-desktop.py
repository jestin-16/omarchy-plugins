#!/usr/bin/env python3
"""Window lifecycle and preferences for the dedicated Lens overlay."""

import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

APP_CLASS = "chrome-lens.google.com__overlay"
HIDDEN_WORKSPACE = "special:google-lens-hidden"
STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "google-lens"
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "google-lens/settings.json"


def read_json(path, default):
    try:
        return json.loads(Path(path).read_text())
    except (OSError, ValueError):
        return default


def save_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2) + "\n")
    temporary.chmod(0o600)
    temporary.replace(path)


def settings():
    config = read_json(CONFIG, {})
    if not isinstance(config, dict):
        config = {}
    return {"mode": "low-memory" if config.get("mode") == "low-memory" else "fast",
            "quality": "original" if config.get("quality") == "original" else "balanced"}


def hypr(*args):
    result = subprocess.run(["hyprctl", *args], capture_output=True, text=True, timeout=3)
    # Window titles inside JSON may legitimately contain the word "error".
    if result.returncode or result.stdout.lstrip().lower().startswith(("error", "couldn't")):
        raise RuntimeError((result.stderr or result.stdout).strip() or "Hyprland command failed")
    return result.stdout


def lens_windows():
    profile_arg = f"--user-data-dir={CONFIG.parent / 'profile'}".encode()
    def belongs_to_profile(window):
        try:
            pid = int(window.get("pid", 0))
            return pid > 0 and profile_arg in Path(f"/proc/{pid}/cmdline").read_bytes().split(b"\0")
        except (OSError, ValueError, TypeError):
            return False
    return [window for window in json.loads(hypr("clients", "-j"))
            if window.get("class") == APP_CLASS or window.get("initialClass") == APP_CLASS
            or belongs_to_profile(window)]


def dispatch(expression):
    hypr("dispatch", expression)


def address(window):
    value = window.get("address", "")
    if not re.fullmatch(r"0x[0-9a-fA-F]+", value):
        raise ValueError("Invalid window address")
    return json.dumps("address:" + value)


def pin(window, value):
    dispatch(f'hl.dsp.window.pin({{ window = {address(window)}, action = "{value}" }})')


def move(window, workspace):
    dispatch(f"hl.dsp.window.move({{ window = {address(window)}, workspace = {json.dumps(str(workspace))}, follow = false }})")


def hide(snapshot):
    windows = [w for w in lens_windows() if w.get("workspace", {}).get("name") != HIDDEN_WORKSPACE]
    record = {"hidden_at": time.time(), "windows": windows}
    # Save before moving so a partial failure can always be undone.
    save_json(snapshot, record)
    try:
        for window in windows:
            if window.get("pinned"):
                pin(window, "off")
            move(window, HIDDEN_WORKSPACE)
        if windows:
            time.sleep(0.18)  # Let the compositor finish the move before freezing the screen.
    except Exception:
        restore(snapshot)
        raise
    return bool(windows)


def restore(snapshot, focus=False):
    record = read_json(snapshot, {})
    if not record.get("windows"):
        Path(snapshot).unlink(missing_ok=True)
        return
    current = {w["address"]: w for w in lens_windows()}
    workspaces = {w["id"] for w in json.loads(hypr("workspaces", "-j"))}
    active = json.loads(hypr("activeworkspace", "-j"))["id"]
    for window in record["windows"]:
        live = current.get(window["address"])
        if not live:
            continue
        if live.get("workspace", {}).get("name") == HIDDEN_WORKSPACE:
            original = window.get("workspace", {}).get("id")
            target = original if original in workspaces else active
            if target == original and target < 0:
                name = window["workspace"]["name"]
                target = name if name.startswith("special:") else "name:" + name
            move(window, target)
        if window.get("pinned") and not live.get("pinned"):
            pin(window, "on")
        if focus:
            dispatch(f"hl.dsp.focus({{ window = {address(window)} }})")
    Path(snapshot).unlink(missing_ok=True)


def expire_hidden(record, windows, monitors, now):
    """Only dismissed windows expire; visible results and CAPTCHA are untouched."""
    if now - record.get("hidden_at", now) < 300:
        return False
    if any(m.get("specialWorkspace", {}).get("name") == HIDDEN_WORKSPACE for m in monitors):
        return False
    recorded = {w["address"] for w in record.get("windows", [])}
    hidden = [w for w in windows if w["address"] in recorded]
    if any(w.get("workspace", {}).get("name") != HIDDEN_WORKSPACE for w in hidden):
        return False
    for window in hidden:
        dispatch(f"hl.dsp.window.close({{ window = {address(window)} }})")
    return True


def idle_watch():
    with (STATE / "idle.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        while settings()["mode"] == "low-memory":
            time.sleep(15)
            # Sharing the capture lock prevents closing a window during a new search.
            with (STATE / "capture.lock").open("w") as capture_lock:
                try:
                    fcntl.flock(capture_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except BlockingIOError:
                    continue
                if settings()["mode"] != "low-memory":
                    return
                snapshot = STATE / "hidden.json"
                record = read_json(snapshot, {})
                if not record.get("windows"):
                    return
                if expire_hidden(record, lens_windows(), json.loads(hypr("monitors", "-j")), time.time()):
                    # A page may veto closing; retain its restore information.
                    time.sleep(0.5)
                    recorded = {w["address"] for w in record["windows"]}
                    if not any(w["address"] in recorded for w in lens_windows()):
                        snapshot.unlink(missing_ok=True)
                    return


def start_idle_watch():
    if settings()["mode"] == "low-memory":
        with (STATE / "desktop.log").open("ab") as log:
            subprocess.Popen([sys.executable, __file__, "idle-watch"], stdin=subprocess.DEVNULL,
                             stdout=log, stderr=log, start_new_session=True)


def main(args):
    STATE.mkdir(parents=True, exist_ok=True)
    action = args[0]
    if action == "idle-watch":
        idle_watch()
    elif action == "prepare":
        hide(args[1])
    elif action == "restore":
        restore(args[1])
    elif action in ("hide", "show", "toggle"):
        snapshot = STATE / "hidden.json"
        hidden = read_json(snapshot, {}).get("windows")
        if action == "show" or action == "toggle" and hidden:
            if hidden:
                restore(snapshot, focus=True)
            else:
                for window in lens_windows():
                    dispatch(f"hl.dsp.focus({{ window = {address(window)} }})")
        elif not hidden:
            if hide(snapshot):
                start_idle_watch()
    elif action in ("mode", "quality"):
        values = ("fast", "low-memory") if action == "mode" else ("balanced", "original")
        if len(args) != 2 or args[1] not in values:
            raise ValueError(f"Use {action} {'|'.join(values)}")
        config = settings()
        config[action] = args[1]
        save_json(CONFIG, config)
        if action == "mode" and (STATE / "hidden.json").exists():
            start_idle_watch()
        print(f"Google Lens {action}: {args[1]}")
    elif action == "status":
        print(json.dumps({**settings(), "last_search": read_json(STATE / "metrics.json", None)}, indent=2))
    else:
        raise ValueError("Unknown desktop action")


if __name__ == "__main__":
    os.umask(0o077)
    try:
        main(sys.argv[1:])
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Google Lens: {error}", file=sys.stderr)
        sys.exit(1)
