"""Phone remote v2: lock/unlock-approve, brightness, auto-brightness once, profiles CRUD, guest start/stop, activity log."""
import json, os, sys, socket
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from autobrightness.drivers.wmi_brightness import get_brightness, set_brightness
from autobrightness.sensors.timeofday import synthetic_lux
from autobrightness.sensors.camera import estimate_lux
from autobrightness.core.fusion import fuse
from autobrightness.core.curve import lux_to_brightness
from pc_service.lock import lock_now
from pc_service.activity import log, recent

PHONE_PIN = os.environ.get("PCREMOTE_PIN", "1234")
NONCE = {}  # ip -> last approval note (replay guard minimal for v2)

def check_pin(h) -> bool:
    return h.get("X-PIN") == PHONE_PIN

class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass
    def _send(self, obj, code=200):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "X-PIN, Content-Type")
        self.end_headers()
        self.wfile.write(body)
    def do_OPTIONS(self):
        self._send({})
    def do_GET(self):
        p = urlparse(self.path).path
        if p == "/":
            self.send_response(200); self.send_header("Content-Type", "text/html"); self.end_headers()
            with open(os.path.join(os.path.dirname(__file__), "..", "..", "phone_web", "index.html"), "rb") as f:
                self.wfile.write(f.read())
            return
        if p == "/status":
            lux_t = synthetic_lux()
            cam, conf = (None, 0.0)  # camera only on demand via /sense to save battery
            lux, src = fuse(cam, conf, lux_t)
            try:
                pc = socket.gethostname()
            except Exception:
                pc = "PC"
            self._send({"brightness": get_brightness(), "lux": lux, "src": src,
                        "suggest": lux_to_brightness(lux), "log": recent(15),
                        "pc": pc,
                        "auto": os.environ.get("PCREMOTE_AUTOBRIGHT", "1") == "1"})
            return
        if p == "/sense":
            cam, conf = estimate_lux()
            lux, src = fuse(cam, conf, synthetic_lux())
            self._send({"cam_lux": cam, "conf": conf, "lux": lux, "src": src,
                        "suggest": lux_to_brightness(lux)})
            return
        if p == "/profiles":
            import glob
            base = os.path.join(os.path.dirname(__file__), "..", "..", "profiles")
            names = [os.path.splitext(os.path.basename(x))[0] for x in glob.glob(os.path.join(base, "*.json")) if not x.endswith("activity.log")]
            self._send({"profiles": names}); return
        if p == "/drives":
            from pc_service.drives import list_drives
            self._send({"drives": list_drives()}); return
        if p.startswith("/folders"):
            from pc_service.drives import list_folders
            from urllib.parse import parse_qs
            q = parse_qs(urlparse(self.path).query)
            path = (q.get("path") or [""])[0]
            self._send(list_folders(path)); return
        if p == "/pick":
            from pc_service.drives import quick_pick
            self._send(quick_pick()); return
        self._send({"err": "not found"}, 404)
    def do_POST(self):
        from pc_service import guest as G
        p = urlparse(self.path).path
        n = int(self.headers.get("Content-Length") or 0)
        try:
            body = json.loads(self.rfile.read(n) or b"{}")
        except Exception:
            body = {}
        if p not in ("/pair-test",):
            if not check_pin(self.headers):
                self._send({"err": "wrong phone PIN"}, 401); return
        ip = self.client_address[0]
        if p == "/lock":
            ok = lock_now(); log(f"lock:{ok} by {ip}"); self._send({"ok": ok}); return
        if p == "/unlock-approve":
            # v2: approval logged; full unlock from lockscreen = v1.0 Credential Provider.
            if NONCE.get(ip) == "pending":
                self._send({"ok": False, "err": "already approved, wait 20s"}); return
            NONCE[ip] = "pending"
            log(f"unlock-approved by {ip}")
            self._send({"ok": True, "note": "approved. On PC press Space + login. Full auto-unlock needs Credential Provider (planned)."})
            return
        if p == "/brightness":
            ok = set_brightness(int(body.get("level", 50)))
            log(f"brightness:{body.get('level')}->{ok}"); self._send({"ok": ok}); return
        if p == "/auto-once":
            lux, src = fuse(None, 0.0, synthetic_lux())
            lvl = lux_to_brightness(lux)
            ok = set_brightness(lvl)
            log(f"auto:{lux:.0f}->{lvl}->{ok}"); self._send({"ok": ok, "level": lvl, "lux": lux}); return
        if p == "/auto":
            on = bool(body.get("on", True))
            os.environ["PCREMOTE_AUTOBRIGHT"] = "1" if on else "0"
            log(f"auto:{'on' if on else 'off'} by {ip}")
            self._send({"ok": True, "auto": on}); return
        if p == "/guest-start":
            try:
                out = G.apply_profile(body.get("name", "guest"))
                self._send({"ok": True, "out": str(out)[:3000]}); return
            except Exception as e:
                self._send({"ok": False, "err": str(e)}, 500); return
        if p == "/guest-stop":
            try:
                out = G.stop_profile(body.get("name", "guest"))
                self._send({"ok": True, "out": str(out)[:3000]}); return
            except Exception as e:
                self._send({"ok": False, "err": str(e)}, 500); return
        if p == "/profile-save":
            try:
                G.save_profile(body.get("name", "guest"), body.get("data", {}))
                log(f"profile-save:{body.get('name')}")
                self._send({"ok": True}); return
            except Exception as e:
                self._send({"ok": False, "err": str(e)}, 500); return
        if p == "/profile-get":
            try:
                self._send({"ok": True, "data": G.load_profile(body.get("name", "guest"))}); return
            except Exception as e:
                self._send({"ok": False, "err": str(e)}, 500); return
        self._send({"err": "not found"}, 404)

if __name__ == "__main__":
    print("Phone UI: http://localhost:5000  PIN=" + PHONE_PIN)
    HTTPServer(("0.0.0.0", 5000), H).serve_forever()
