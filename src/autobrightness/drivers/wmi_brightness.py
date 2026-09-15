"""Internal laptop brightness via WMI (no extra deps, uses PowerShell CIM)."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))
from winutil import run as _run

def _ps(cmd: str) -> str:
    r = _run(["powershell", "-NoProfile", "-Command", cmd],
             capture_output=True, text=True, timeout=15)
    return (r.stdout or "").strip()

def get_brightness() -> int | None:
    out = _ps("(Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorBrightness | Select-Object -First 1).CurrentBrightness")
    try:
        return int(out.strip())
    except Exception:
        return None

def set_brightness(level: int, timeout: int = 1) -> bool:
    level = max(0, min(100, int(level)))
    cmd = f"(Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorBrightnessMethods | Select-Object -First 1 | Invoke-CimMethod -MethodName WmiSetBrightness -Arguments @{{Timeout={timeout}; Brightness={level}}}) | Out-Null; echo OK"
    return "OK" in _ps(cmd)

if __name__ == "__main__":
    print("current:", get_brightness())
