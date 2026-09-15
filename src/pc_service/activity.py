import os, datetime
BASE = os.path.join(os.path.dirname(__file__), "..", "..", "profiles")
LOGF = os.path.join(BASE, "activity.log")

def log(msg: str):
    os.makedirs(BASE, exist_ok=True)
    with open(LOGF, "a", encoding="utf-8") as f:
        f.write(f"{datetime.datetime.now().isoformat(timespec='seconds')} {msg}\n")

def recent(n: int = 20) -> list[str]:
    try:
        with open(LOGF, encoding="utf-8") as f:
            return f.read().strip().splitlines()[-n:]
    except Exception:
        return []
