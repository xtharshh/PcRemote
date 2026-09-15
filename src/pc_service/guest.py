import json, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from winutil import run as _run

# admin = owner, no new user. guest/kid = real Standard users.
USERS = {"admin": None, "guest": "PC-Guest", "kid": "PC-Kid"}
BASE = os.path.join(os.path.dirname(__file__), "..", "..", "profiles")

def _ps(cmd: str) -> str:
    r = _run(["powershell", "-NoProfile", "-Command", cmd],
             capture_output=True, text=True, timeout=30)
    return (r.stdout or "") + (r.stderr or "")

def _user(name: str) -> str | None:
    return USERS.get(name, f"PC-{name.capitalize()}")

def create_user(name: str, password: str = "Guest1234!") -> str:
    user = _user(name)
    if user is None:  # admin = owner, nothing to create
        return "admin-owner-no-user-needed"
    cmd = f"""
$u=Get-LocalUser -Name '{user}' -ErrorAction SilentlyContinue
if (-not $u) {{ New-LocalUser -Name '{user}' -Password (ConvertTo-SecureString '{password}' -AsPlainText -Force) -AccountNeverExpires }}
Enable-LocalUser -Name '{user}'
echo DONE
"""
    return _ps(cmd)

def disable_user(name: str) -> str:
    user = _user(name)
    if user is None:
        return "admin-nothing-to-disable"
    return _ps(f"Disable-LocalUser -Name '{user}'; echo DONE")

# keep old names working
def create_guest(password: str = "Guest1234!") -> str:
    return create_user("guest", password)

def block_folder(path: str, profile: str = "guest") -> str:
    user = _user(profile)
    if not path or not os.path.exists(path):
        return f"skip-missing:{path}"
    if user is None:
        return "admin-no-block"
    r = _run(["icacls", path, "/deny", f"{user}:(OI)(CI)F"],
               capture_output=True, text=True, timeout=15)
    return (r.stdout or "") + (r.stderr or "")

def unblock_folder(path: str, profile: str = "guest") -> str:
    user = _user(profile)
    if user is None:
        return "admin-nothing"
    r = _run(["icacls", path, "/remove:d", user],
               capture_output=True, text=True, timeout=15)
    return (r.stdout or "") + (r.stderr or "")

def load_profile(name: str = "guest") -> dict:
    with open(os.path.join(BASE, f"{name}.json"), encoding="utf-8") as f:
        return json.load(f)

def save_profile(name: str, data: dict):
    os.makedirs(BASE, exist_ok=True)
    with open(os.path.join(BASE, f"{name}.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)

def apply_profile(name: str = "guest") -> dict:
    from .enforce import hide_settings_pages, start_app_watcher, start_time_limit
    from .activity import log
    if name == "admin":
        # admin = remove all blocks, stop watchers
        return stop_profile("guest") | stop_profile("kid") | {"admin": "full-access-restored"}
    p = load_profile(name)
    out = {"user": create_user(name)}
    for folder in p.get("folders_deny", []):
        out[f"folder:{folder}"] = block_folder(folder, name)
    vis = p.get("settings_hide", "")
    if vis:
        out["settings"] = hide_settings_pages(f"hide:{vis}" if not vis.startswith("hide:") else vis)
    apps = p.get("apps_deny", [])
    if apps:
        start_app_watcher(apps)
        out["appwatch"] = f"watching:{apps}"
    mins = int(p.get("time_minutes", 0) or 0)
    if mins > 0:
        start_time_limit(mins, on_expire=lambda: stop_profile(name))
        out["timer"] = f"{mins}min"
    log(f"guest-start:{name}")
    return out

def stop_profile(name: str = "guest") -> dict:
    from .enforce import show_settings_pages, stop_app_watcher
    from .activity import log
    out = {}
    try:
        p = load_profile(name)
    except Exception:
        p = {}
    for folder in p.get("folders_deny", []):
        try:
            out[f"unblock:{folder}"] = unblock_folder(folder, name)
        except Exception as e:
            out[f"unblock:{folder}"] = str(e)
    try:
        out["settings"] = show_settings_pages()
    except Exception as e:
        out["settings"] = str(e)
    try:
        stop_app_watcher()
    except Exception:
        pass
    out["user"] = disable_user(name)
    log(f"guest-stop:{name}")
    return out
