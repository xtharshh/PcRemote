"""Always-on daemon: phone API + auto-brightness in ONE process, no console needed.
Run with pythonw.exe so no terminal window appears.
Logs to profiles/daemon.log. Stop via Task Scheduler or stop_daemon.ps1."""
import os, sys, time, threading, traceback, json
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
BASE = os.path.join(os.path.dirname(__file__), "..", "..")
BEACON_PORT = 59871

def dlog(msg: str):
    try:
        os.makedirs(os.path.join(BASE, "profiles"), exist_ok=True)
        with open(os.path.join(BASE, "profiles", "daemon.log"), "a", encoding="utf-8") as f:
            f.write(time.strftime("%Y-%m-%d %H:%M:%S ") + msg + "\n")
    except Exception:
        pass

def run_server():
    from http.server import HTTPServer
    from pc_service.server import H
    port = int(os.environ.get("PCREMOTE_PORT", "5000"))
    while True:  # retry instead of crash-looping the scheduled task
        try:
            srv = HTTPServer(("0.0.0.0", port), H)
            dlog(f"server on 0.0.0.0:{port}")
            srv.serve_forever()
            return
        except OSError as e:
            dlog(f"port busy, retry in 15s: {e}")
            time.sleep(15)

def _bcast_targets() -> set:
    import socket
    targets = {"255.255.255.255"}
    try:
        for info in socket.getaddrinfo(socket.gethostname(), None,
                                        socket.AF_INET):
            ip = info[4][0]
            if ip.startswith("127."):
                continue
            parts = ip.split(".")
            if len(parts) == 4:
                targets.add(".".join(parts[:3] + ["255"]))
    except Exception as e:
        dlog("bcast-enum-err " + str(e)[:120])
    return targets

def run_beacon():
    """UDP broadcast every 3s so the phone finds the PC without typing IP."""
    import socket
    if os.environ.get("PCREMOTE_BEACON", "1") != "1":
        return
    port = int(os.environ.get("PCREMOTE_PORT", "5000"))
    try:
        name = socket.gethostname()
    except Exception:
        name = "PC"
    msg = json.dumps({"app": "PCRemote", "name": name, "port": port}).encode()
    dlog("beacon on")
    while True:
        try:
            for target in _bcast_targets():
                s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                try:
                    s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
                    s.sendto(msg, (target, BEACON_PORT))
                finally:
                    s.close()
        except Exception as e:
            dlog("beacon-err " + str(e)[:150])
        time.sleep(3)

def run_brightness():
    from autobrightness.sensors.timeofday import synthetic_lux
    from autobrightness.core.fusion import fuse
    from autobrightness.core.curve import lux_to_brightness, Smoother
    from autobrightness.drivers.wmi_brightness import get_brightness, set_brightness
    if os.environ.get("PCREMOTE_AUTOBRIGHT", "1") != "1":
        return
    sm = Smoother()
    interval = int(os.environ.get("PCREMOTE_BRIGHT_INTERVAL", "8"))
    dlog("auto-brightness on")
    while True:
        try:
            lux, _ = fuse(None, 0.0, synthetic_lux())
            target = lux_to_brightness(lux)
            cur = get_brightness()
            nxt = sm.next(target)
            if nxt is not None and cur is not None and abs(nxt - cur) >= 4:
                set_brightness(nxt)
                dlog(f"bright {cur}->{nxt} (lux {lux:.0f})")
        except Exception as e:
            dlog("bright-err " + str(e)[:200])
        time.sleep(interval)

if __name__ == "__main__":
    # optional argv: daemon.py [PIN] [PORT] (so Task Scheduler needs no env support)
    if len(sys.argv) > 1:
        os.environ["PCREMOTE_PIN"] = sys.argv[1]
    if len(sys.argv) > 2:
        os.environ["PCREMOTE_PORT"] = sys.argv[2]
    # sync server PIN with env at import time
    try:
        import pc_service.server as S
        S.PHONE_PIN = os.environ.get("PCREMOTE_PIN", S.PHONE_PIN)
    except Exception as e:
        dlog("pin-sync-err " + str(e)[:150])
    dlog("daemon start")
    try:
        t1 = threading.Thread(target=run_server, daemon=True)
        t2 = threading.Thread(target=run_brightness, daemon=True)
        t3 = threading.Thread(target=run_beacon, daemon=True)
        t1.start(); t2.start(); t3.start()
        while True:
            time.sleep(3600)
    except Exception:
        dlog(traceback.format_exc()[-1000:])
