from datetime import datetime

def synthetic_lux(hour: int | None = None) -> float:
    """Fallback when no camera/ALS: 10 lux night, 300 lux day."""
    h = datetime.now().hour if hour is None else hour
    if 7 <= h < 9:
        return 120.0
    if 9 <= h < 17:
        return 300.0
    if 17 <= h < 19:
        return 120.0
    if 19 <= h < 22:
        return 60.0
    return 10.0
