"""Fuse camera + time sensors into one lux value."""
try:
    from autobrightness.sensors.timeofday import synthetic_lux
except ImportError:
    from ..sensors.timeofday import synthetic_lux

def fuse(cam_lux=None, cam_conf=0.0, time_lux=None) -> tuple[float, str]:
    if time_lux is None:
        time_lux = synthetic_lux()
    if cam_lux is None or cam_conf <= 0.1:
        return time_lux, "time"
    # weighted: camera trusted when conf high
    w_cam = max(0.0, min(1.0, cam_conf))
    w_time = 1.0 - w_cam * 0.7  # time always contributes a bit for stability
    lux = (cam_lux * w_cam + time_lux * w_time) / (w_cam + w_time)
    src = "camera+time" if w_cam > 0.4 else "time+camera"
    return lux, src
