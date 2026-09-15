import ctypes
def lock_now() -> bool:
    try:
        return bool(ctypes.windll.user32.LockWorkStation())
    except Exception:
        return False
