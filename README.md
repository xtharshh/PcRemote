<div align="center">

# 🖥️📱 LumiLink

### Your Windows PC, remotely yours — brightness, profiles & lock, from your phone.

![Windows](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)

Windows never got Mac-style auto-brightness, Apple-Watch-style phone unlock,
or per-person profiles you control from your pocket. **LumiLink fixes all three**
with small modules sharing one sensor + service stack.

<a href="https://www.buymeacoffee.com/xtharshh">
<img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black" alt="Buy Me A Coffee" />
</a>

*If LumiLink saved your eyes or your privacy, consider fueling the next feature. ☕*

</div>

---

## ✨ Features

| | What | How |
|---|---|---|
| 🔆 | **Auto-brightness** | Screen follows room light — webcam sensor + time-of-day fallback, log curve, flicker-free smoothing |
| 👥 | **Profiles: admin / guest / kid** | Phone decides which folders, Settings pages & apps each person may open + time limits |
| 🔒 | **Phone remote** | Lock instantly, approve unlock, brightness slider, profiles — PIN + fingerprint that never leave your phone |
| 📡 | **WiFi auto-find** | PC broadcasts over LAN; the app finds it, no typing IP |
| 💡 | **Folder picker** | Real disks + folders (`C:\`, `D:\APEX`…) with free space, search, tap-to-block |
| 🪟 | **Zero windows** | Daemon runs via `pythonw` + `CREATE_NO_WINDOW` — no flashing consoles, starts at logon |

---

## 🏗️ How it works

```
Phone (PIN/biometric gate — secrets stay on phone)
  │  LAN  http://<PC-IP>:5000   header X-PIN     UDP beacon :59871
  ▼
PC daemon (pythonw, no window, starts at logon, restarts on crash)
  ├── phone API ......... src/pc_service/server.py
  ├── auto-brightness ... src/autobrightness/service.py (sense → fuse → map → smooth → apply)
  ├── guest enforce ..... src/pc_service/guest.py + enforce.py
  └── disks/folders ..... src/pc_service/drives.py
Display drivers: WMI (laptop built-in) │ DDC/CI VCP 0x10 (external, planned)
```

**Sensors** (pluggable): webcam lux (`sensors/camera.py`, needs OpenCV) ·
time-of-day curve (`sensors/timeofday.py`) · HID ALS if present.
**Fusion**: weighted camera + time. **Mapping**: logarithmic lux→brightness.
**Smoothing**: EMA + 4% hysteresis + rate limit.

---

## 📁 Project structure

```
src/autobrightness/   drivers/wmi_brightness.py · sensors/timeofday.py
                      sensors/camera.py · core/curve.py · core/fusion.py
                      service.py (loop)
src/pc_service/       server.py · daemon.py · guest.py · enforce.py
                      drives.py · lock.py · activity.py
src/winutil.py        CREATE_NO_WINDOW subprocess wrapper (no flashing windows)
config/default.json   profiles/admin.json · profiles/guest.json · profiles/kid.json
scripts/              run_all.ps1 · install_autostart.ps1
                      uninstall_autostart.ps1 · status_daemon.ps1 · set_brightness.ps1
phone_web/            mobile web remote — no install, open from phone browser
phone_app/            Android app (Expo / React Native)
pc_remote/            Flutter app, Material 3 (recommended — signed release APK ready)
tests/test_curve.py
```

---

## 🚀 PC setup

### Requirements
- Windows 10/11 · Python 3.11+ (`python --version`) · same WiFi for PC + phone
- Optional: `pip install opencv-python` (webcam light sensor)

### 1️⃣ Try it (visible window, for testing)
```powershell
Set-Location D:\OpenSourceProjects\autoBrightness
python src/pc_service/server.py
# Phone UI: http://localhost:5000   PIN=1234
```

### 2️⃣ Always-on, no terminal (recommended)
Runs `daemon.py` with `pythonw.exe` via Task Scheduler — starts at logon,
restarts on crash, no admin needed:
```powershell
scripts/install_autostart.ps1 -Pin "1234" -Port 5000
scripts/status_daemon.ps1     # State=Running? API OK?
```
Change PIN anytime by re-running install with another `-Pin`.
Logs: `profiles/daemon.log` · Pause: `Stop-ScheduledTask -TaskName "PCRemote"`
· Remove: `scripts/uninstall_autostart.ps1`

### 3️⃣ Auto-brightness loop
Inside the daemon (every 8 s, time-of-day curve). Manual test:
```powershell
python src/autobrightness/service.py --once
python src/autobrightness/service.py --camera --once   # needs opencv-python
```

### 4️⃣ Windows Firewall (if the phone can't reach the PC)
```powershell
New-NetFirewallRule -DisplayName "PCRemote" -Direction Inbound `
  -LocalPort 5000 -Protocol TCP -Action Allow
```

---

## 📲 Phone — no app install (mobile web)

1. Same WiFi as PC · find PC IP via `ipconfig` (e.g. `192.168.1.4`)
2. Open `http://192.168.1.4:5000`, enter PIN
3. **Lock / Unlock** — lock is instant; unlock logs an approval, then press
   Space on the PC and log in (true lockscreen unlock needs the planned C++
   Credential Provider — see Roadmap)
4. **Brightness** — slider or Auto once
5. **Profiles** — Load / Save / Start / Stop `admin | guest | kid`
6. **Block folders picker** — disk dropdown with free/total GB → folder list
   (double-tap to enter, Up to go back) → select → `+ Add to block list`

## 🤖 Android app (Expo, no Android Studio)

`phone_app/` — home · bright · profiles · folders tabs, fingerprint gate,
IP/PIN in SecureStore (never leave the phone):
```powershell
Set-Location phone_app
npm install
npx expo start        # scan QR with Expo Go (Play Store), same WiFi
```

## 💙 LumiLink app (recommended) — `pc_remote/`

Skill-built UI (seed Material 3, composed widgets, implicit animations,
`ListView.builder`, `Semantics`, responsive cards):
gate with fingerprint + **Find my PC on WiFi** (UDP beacon with HTTP
subnet-sweep fallback, zero typing), Home shows the **PC name on WiFi**,
dashboard with animated brightness ring + auto-brightness toggle +
lock/unlock + activity timeline, brightness slider,
**visual profile editor** (chips + sliders, no JSON, incl. **Admin —
full access**), folder picker with search that saves straight into
a profile.

```powershell
Set-Location pc_remote
flutter pub get
flutter analyze          # clean
flutter test             # 3/3 pass
flutter devices          # phone visible (USB debugging on)
flutter run              # install + launch
flutter build apk --release   # keep-forever APK
```

**Signed release APK** already built (v1.1.0):
`pc_remote/build/app/outputs/flutter-apk/app-release.apk` (50 MB).
Reinstall fresh so Android grants the LAN/WiFi permissions
(same WiFi, allow WiFi/location when asked).

Release signing: `pc_remote/android/key.properties` + `.jks` are gitignored —
generate your own with `keytool -genkeypair` (see
`pc_remote/android/app/build.gradle.kts`); without them the build falls back
to debug keys. Release cert SHA-256:
`248ecb4d17238159c8e145c91d15cff94e74209fe86351164765443d97f1e09a`.

Older draft in `phone_flutter/` (same 4 tabs, simpler UI) — kept for reference.

---

## 👥 Profiles

| Profile | Windows user | Blocks | Time |
|---|---|---|---|
| admin | Owner (no new user) | none — Start clears all blocks | — |
| guest | `PC-Guest` (Standard) | your folders + accounts/bluetooth/update pages + regedit/powershell | 30 min |
| kid | `PC-Kid` (Standard) | guest + recovery/apps pages + cmd/steam | 60 min |

Edit `profiles/guest.json` / `kid.json`, or from the phone (Load → edit →
Save → Start). Guests are **real Standard users**: NTFS deny via `icacls`,
Settings-hide policy, app-killer watcher, auto-logoff timer.

---

## 🔌 API reference (POST needs header `X-PIN: <pin>`)

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/status` | brightness, lux, suggestion, PC name, recent log |
| GET | `/sense` | camera + fused lux |
| GET | `/profiles` | profile names |
| GET | `/drives` | disks + free/total GB |
| GET | `/folders?path=D:\` | folders in path |
| GET | `/pick` | drives + specials + top folders |
| POST | `/lock` | lock Windows now |
| POST | `/unlock-approve` | log phone approval |
| POST | `/brightness` `{"level":50}` | set brightness |
| POST | `/auto-once` | sense + apply once |
| POST | `/guest-start` `{"name":"guest"}` | start profile |
| POST | `/guest-stop` | stop profile, restore |
| POST | `/profile-get` · `/profile-save` | read / write profile JSON |

---

## 🛑 Stop / start / remove

```powershell
Stop-ScheduledTask -TaskName "PCRemote"    # pause (keeps config)
Start-ScheduledTask -TaskName "PCRemote"   # resume
scripts/uninstall_autostart.ps1            # remove forever
```

## 🩺 Troubleshooting

- **Black shell flashing in a loop** — fixed in `src/winutil.py`: every
  background call uses `CREATE_NO_WINDOW`. If it returns, stop the task and
  check `profiles/daemon.log`.
- **Phone can't reach PC** — same WiFi? Firewall rule for TCP 5000?
  `scripts/status_daemon.ps1` says API OK?
- **Wrong PIN** — API returns 401; re-run install with your PIN.
- **Port busy** — daemon retries every 15 s by itself.
- **`Not supported` brightness on desktop** — WMI works on laptops; desktops
  need DDC/CI (planned, VCP 0x10).
- **Guest users need admin once** — creating `PC-Guest`/`PC-Kid` and the
  HKLM Settings-hide key require an elevated shell the first time.

## 🔐 Security notes

- LAN only — never expose port 5000 to the internet.
- Default PIN `1234` is a demo — change it on install.
- Phone password/biometric unlocks the *phone app only*; the PC receives
  just an approval (HMAC design planned for v1.0).
- Without BitLocker + BIOS password, a Guest can boot USB to bypass file
  ACLs — this tool is privacy/control, not disk encryption.

## 🗺️ Roadmap

- DDC/CI driver for external monitors (VCP 0x10)
- True Tone (ambient color temperature via gamma ramp)
- Battery limiter 80% (per-OEM WMI)
- C++ Credential Provider tile for true lockscreen phone-unlock
- X25519 pairing + HMAC approvals replacing the demo PIN

---

<div align="center">

### ☕ Support LumiLink

Built late at night, tested on a real laptop, signed, scanned and shipped.
If it saved your eyes or your files —

<a href="https://www.buymeacoffee.com/xtharshh">
<img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black" alt="Buy Me A Coffee" />
</a>

**github.com/xtharshh** · PRs and ideas welcome.

</div>
