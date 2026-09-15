"""Guest enforcement: Settings-hide, app-killer, time-limit. Stdlib only, admin needed for some ops."""
import threading, time, os
import sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from winutil import run as _run
from .activity import log

def _ps(cmd: str) -> str:
    r = _run(["powershell", "-NoProfile", "-Command", cmd],
             capture_output=True, text=True, timeout=30)
    return (r.stdout or "") + (r.stderr or "")

def hide_settings_pages(visibility: str) -> str:
    # HKLM policy hides pages for all users (simple + reliable for MVP).
    # Example visibility: "hide:accounts;bluetooth;windowsupdate"
    cmd = f"""
New-Item -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer' -Force | Out-Null
Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer' -Name 'SettingsPageVisibility' -Value '{visibility}'
echo DONE
"""
    out = _ps(cmd)
    log(f"settings-hide:{visibility}")
    return out

def show_settings_pages() -> str:
    cmd = "Remove-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer' -Name 'SettingsPageVisibility' -ErrorAction SilentlyContinue; echo DONE"
    return _ps(cmd)

def running_processes() -> str:
    r = _run(["tasklist", "/FO", "CSV", "/NH"], capture_output=True, text=True, timeout=15)
    return r.stdout or ""

def kill_blocked(apps_deny: list[str]) -> list[str]:
    killed = []
    try:
        procs = running_processes().lower()
        for app in apps_deny:
            a = app.lower()
            if a in procs:
                _run(["taskkill", "/F", "/IM", app], capture_output=True, timeout=10)
                killed.append(app)
                log(f"kill:{app}")
    except Exception as e:
        log(f"kill-err:{e}")
    return killed

_watcher_stop = threading.Event()

def start_app_watcher(apps_deny: list[str], interval_s: int = 5):
    _watcher_stop.clear()
    def loop():
        while not _watcher_stop.is_set():
            kill_blocked(apps_deny)
            time.sleep(interval_s)
    t = threading.Thread(target=loop, daemon=True)
    t.start()
    return t

def stop_app_watcher():
    _watcher_stop.set()

def start_time_limit(minutes: int, on_expire=None):
    def loop():
        time.sleep(max(1, minutes) * 60)
        log(f"time-expired:{minutes}min")
        try:
            if on_expire:
                on_expire()
        finally:
            # force guest logoff (owner stays). Safe: only logs off, no delete.
            _run(["logoff"], capture_output=True, timeout=10)
    t = threading.Thread(target=loop, daemon=True)
    t.start()
    return t
