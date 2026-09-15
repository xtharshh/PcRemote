"""Windows-safe subprocess: never opens a visible console window (CREATE_NO_WINDOW)."""
import subprocess
import sys

NW = 0x08000000 if sys.platform == "win32" else 0

def run(*args, **kwargs):
    if sys.platform == "win32":
        kwargs.setdefault("creationflags", NW)
    return subprocess.run(*args, **kwargs)
