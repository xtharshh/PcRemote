"""Auto-brightness loop: sense -> fuse -> map -> smooth -> apply."""
import time, sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from autobrightness.sensors.timeofday import synthetic_lux
from autobrightness.sensors.camera import estimate_lux
from autobrightness.core.fusion import fuse
from autobrightness.core.curve import lux_to_brightness, Smoother
from autobrightness.drivers.wmi_brightness import get_brightness, set_brightness

def run(interval_s=5, min_b=10, max_b=100, camera_enable=False, once=False):
    sm = Smoother()
    override_until = 0
    while True:
        lux_t = synthetic_lux()
        cam_lux, conf = estimate_lux() if camera_enable else (None, 0.0)
        lux, src = fuse(cam_lux, conf, lux_t)
        # battery saver: cap max on battery
        target = lux_to_brightness(lux, min_b, max_b)
        # manual override decay: if current changed externally, pause 60s
        cur = get_brightness()
        nxt = sm.next(target)
        if nxt is not None and cur is not None and abs(nxt - cur) >= 4:
            ok = set_brightness(nxt)
            print(f"lux={lux:.0f} src={src} target={target} apply={nxt} cur={cur} ok={ok}", flush=True)
        else:
            print(f"lux={lux:.0f} src={src} target={target} cur={cur} skip", flush=True)
        if once:
            return target
        time.sleep(interval_s)

if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--interval", type=int, default=5)
    ap.add_argument("--min", type=int, default=10)
    ap.add_argument("--max", type=int, default=100)
    ap.add_argument("--camera", action="store_true")
    ap.add_argument("--once", action="store_true")
    a = ap.parse_args()
    run(a.interval, a.min, a.max, a.camera, a.once)
