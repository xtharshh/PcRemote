"""Disks + folders enumeration, stdlib only."""
import os, shutil, string, ctypes, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from winutil import run as _run

def list_drives() -> list[dict]:
    out = []
    try:
        GetDriveTypeW = ctypes.windll.kernel32.GetDriveTypeW
    except Exception:
        GetDriveTypeW = None
    for L in string.ascii_uppercase:
        root = f"{L}:\\"
        if not os.path.exists(root):
            continue
        dtype = ""
        if GetDriveTypeW:
            try:
                t = GetDriveTypeW(root)
                dtype = {0: "unknown", 1: "noroot", 2: "removable", 3: "fixed",
                         4: "remote", 5: "cdrom", 6: "ramdisk"}.get(t, str(t))
            except Exception:
                pass
        try:
            u = shutil.disk_usage(root)
            total_gb = round(u.total / 1e9, 1)
            free_gb = round(u.free / 1e9, 1)
        except Exception:
            total_gb = free_gb = 0
        label = ""
        try:
            r = _run(["powershell", "-NoProfile", "-Command",
                f"(Get-CimInstance Win32_LogicalDisk -Filter \"DeviceID='{L}:'\").VolumeName"],
                capture_output=True, text=True, timeout=10)
            label = (r.stdout or "").strip()
        except Exception:
            pass
        out.append({"root": root, "label": label, "total_gb": total_gb,
                    "free_gb": free_gb, "type": dtype})
    return out

SKIP = {"$RECYCLE.BIN", "System Volume Information", "Recovery", "$SysReset"}

def list_folders(path: str, max_items: int = 200) -> dict:
    if not path or not os.path.isdir(path):
        return {"path": path, "folders": [], "err": "not a folder"}
    items = []
    try:
        with os.scandir(path) as it:
            for e in it:
                try:
                    if not e.is_dir(follow_symlinks=False):
                        continue
                except Exception:
                    continue
                if e.name in SKIP:
                    continue
                items.append({"name": e.name, "full": e.path})
                if len(items) >= max_items:
                    break
    except Exception as ex:
        return {"path": path, "folders": [], "err": str(ex)}
    items.sort(key=lambda x: x["name"].lower())
    return {"path": path, "folders": items}

def quick_pick() -> dict:
    """Drives + home dirs + top folders of each drive (1 level)."""
    home = os.path.expanduser("~")
    specials = []
    for n in ("Desktop", "Documents", "Downloads", "Pictures", "Videos", "OneDrive"):
        p = os.path.join(home, n)
        if os.path.isdir(p):
            specials.append({"name": n, "full": p})
    drives = list_drives()
    tops = {}
    for d in drives:
        if d["type"] in ("fixed", "removable", ""):
            tops[d["root"]] = list_folders(d["root"])["folders"][:100]
    return {"drives": drives, "specials": specials, "tops": tops}
