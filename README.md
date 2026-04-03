# WGtech AI Starter Pack — Dashboard

> **Before continuing:** You must have completed the full **AI Starter Pack Setup Guide** (the HTML guide included in your kit) before running anything here. This README picks up exactly where that guide ends — after the Voyager SDK is installed and inference is confirmed working inside the `voyager-sdk` container.

---

## Prerequisites checklist

Work through this before touching any script. Every item must be true.

- [ ] Raspberry Pi OS (64-bit) is installed and fully updated
- [ ] PCIe Gen3 is enabled via `raspi-config`
- [ ] Docker is installed and `docker run hello-world` works
- [ ] Axelera Metis driver is installed — `dkms status` shows `installed`
- [ ] `voyager-sdk` container exists — `docker ps -a` shows it
- [ ] Inference works — you ran `./inference.py yolov5s-v7-coco media/traffic1_1080p.mp4` inside the container and saw FPS output

If any item above is not checked, **stop here** and complete the AI Starter Pack Setup Guide first.

---

## File overview

```
starter-kit/
├── start.sh              ← main entry point — run this every time
├── start_voyager.sh      ← starts voyager-sdk container + MediaMTX
├── setup.sh              ← installs MediaMTX, builds .env, handles USB camera
├── docker-compose.yml    ← frontend + backend containers (managed by scripts)
├── voyager-service/
│   ├── ai_server.py      ← FastAPI server that runs inside voyager-sdk
│   ├── ai_inference.py   ← inference lifecycle management
│   └── wginference.py    ← AIPU inference wrapper
└── data/                 ← created automatically on first run
    ├── recordings/
    ├── uploads/
    ├── models/
    └── hls/
```

---

## First-time setup

### Step 1 — Make scripts executable

Open a terminal on the Pi and navigate to this folder:

```bash
cd ~/starter-kit        # or wherever you placed this folder
chmod +x start.sh start_voyager.sh setup.sh
```

### Step 2 — Make sure xhost permissions are set

This is required every time the Pi reboots. Run on the host before anything else:

```bash
xhost +local:root
xhost +local:docker
```

### Step 3 — Make sure the kernel module is loaded

```bash
sudo modprobe metis
```

Verify it loaded:

```bash
lsmod | grep metis
```

You should see `metis` in the output. If not, check that the Axelera driver was installed correctly per the setup guide.

### Step 4 — (Optional) Connect your USB camera

If you have a USB camera, plug it in **before** running `start.sh`. The setup script will detect it automatically and enable it in the dashboard. If you plug it in later, just run `./start.sh` again — it re-checks on every run.

### Step 5 — Run start.sh

```bash
./start.sh
```

This does three things in order:

1. **Starts the Voyager SDK** — launches the `voyager-sdk` container, copies service files into it, installs dependencies, detects the container IP, updates `.env`, and starts `ai_server.py`
2. **Runs setup** — installs MediaMTX if needed, detects your USB camera and updates `docker-compose.yml` accordingly
3. **Starts the dashboard** — pulls `docker compose up`, waits for the backend health check to pass

When it finishes you will see:

```
╔══════════════════════════════════════════════════════════╗
║  ✓  WGtech AI Dashboard is running                      ║
╠══════════════════════════════════════════════════════════╣
║  Dashboard:      http://localhost                        ║
║  Backend API:    http://localhost/api                    ║
╚══════════════════════════════════════════════════════════╝
```

Open a browser on the Pi and go to **http://localhost**.

---

## Every boot — what to run

After a Pi reboot, run these three things in order before `./start.sh`:

```bash
# 1. Reload the AIPU kernel module
sudo modprobe metis

# 2. Grant display access to Docker (resets on every reboot)
xhost +local:root
xhost +local:docker

# 3. Start everything
./start.sh
```

> **Why xhost?** The Voyager SDK renders inference output to the display. Without xhost permissions set on the host, the display connection from inside Docker is refused. This is not persistent across reboots — you must run it every time.

---

## USB camera behaviour

`setup.sh` checks for `/dev/video0` on every run and automatically updates `docker-compose.yml`:

| Camera state | What happens |
|---|---|
| Plugged in before `./start.sh` | Detected, device passed through to backend container, full USB features available in dashboard |
| Not plugged in | Warning printed, device line commented out in compose file, USB features blocked in dashboard |
| Plugged in after containers started | Run `./start.sh` again — it will detect the camera, update compose, and restart containers |

When no camera is found you will see:

```
┌──────────────────────────────────────────────────────────┐
│  ⚠  No USB camera detected at /dev/video0                │
│                                                          │
│  USB camera features will be blocked in the dashboard.   │
│                                                          │
│  To enable USB camera access:                            │
│    1. Plug in your USB camera                            │
│    2. Run  ./start.sh  again                             │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

> **Do not edit the `devices:` block in `docker-compose.yml` manually.** It is overwritten automatically by `setup.sh` on every run.

---

## Useful commands

### View logs

```bash
# Dashboard backend
sudo docker logs -f dashboard-backend

# Voyager SDK / inference server
docker exec voyager-sdk tail -f /tmp/ai_server.log

# MediaMTX streaming server
tail -f /tmp/mediamtx.log
```

### Check running containers

```bash
sudo docker ps
```

You should see `dashboard-frontend`, `dashboard-backend`, and `voyager-sdk` (voyager-sdk will show as running but not in compose — that is expected).

### Check voyager-sdk is healthy

```bash
docker exec voyager-sdk curl -s http://localhost:8001/health
```

### Restart everything

```bash
./start.sh
```

`start.sh` is safe to re-run at any time. It stops and restarts the dashboard containers cleanly, re-detects the camera, and re-syncs the voyager IP in `.env`.

### Stop everything

```bash
sudo docker compose down
docker exec voyager-sdk pkill -f ai_server.py 2>/dev/null || true
pkill -f mediamtx 2>/dev/null || true
```

---

## Troubleshooting

### Dashboard won't load at http://localhost

Check the frontend container is running:
```bash
sudo docker ps | grep frontend
sudo docker logs dashboard-frontend
```

If the container is not running, check `sudo docker compose up` output for errors.

### Backend health check fails / keeps restarting

```bash
sudo docker logs dashboard-backend
```

Most common cause: `.env` has the wrong `VOYAGER_SDK_URL`. Check what IP is in `.env`:
```bash
cat .env | grep VOYAGER_SDK_URL
```

Then verify the voyager-sdk is reachable at that IP:
```bash
curl http://<that-ip>:8001/health
```

If it fails, re-run `./start.sh` — it will re-detect and update the IP.

### voyager-sdk health check fails at end of start_voyager.sh

```bash
docker exec voyager-sdk tail -40 /tmp/ai_server.log
```

If you see AIPU / device errors, the Metis card may be in a bad state. Run the reboot recovery:

```bash
# Exit any container shells, then:
sudo reboot
# After reboot:
sudo modprobe metis
xhost +local:root
xhost +local:docker
./start.sh
```

### axdevice shows no devices inside voyager-sdk

```bash
# On the host — check if the card is visible at PCIe level
lspci | grep -i axelera
```

If nothing shows: power-cycle the Pi (full shutdown, not just reboot) and re-check physical connections per the setup guide.

If the card shows in `lspci` but not `axdevice`, the kernel module is probably not loaded:
```bash
sudo modprobe metis
lsmod | grep metis
```

### USB camera detected but still no video in dashboard

Check the device was actually passed through:
```bash
sudo docker inspect dashboard-backend | grep -A5 Devices
```

If empty, the compose file may have the device line commented out. Re-run `./start.sh` with the camera plugged in.

Also check the camera isn't locked by another process on the host:
```bash
fuser /dev/video0
```

---

## What each script does (summary)

| Script | When to run | What it does |
|---|---|---|
| `start.sh` | Every boot, or to restart | Runs `start_voyager.sh` → `setup.sh` → `docker compose up` in order |
| `start_voyager.sh` | Called by `start.sh` | Starts MediaMTX, starts `voyager-sdk` container, copies service files, detects IP, starts `ai_server.py` |
| `setup.sh` | Called by `start.sh` | Installs MediaMTX if missing, creates/updates `.env`, creates data dirs, detects USB camera and updates `docker-compose.yml` |

---

## Architecture overview

```
┌─────────────────── Raspberry Pi 5 Host ───────────────────────┐
│                                                                │
│  MediaMTX (host process)                                       │
│  RTSP :8554  ─────────────────────────────────────────┐       │
│  HLS  :8888  ─────────────────────────────────────────┤       │
│                                                        │       │
│  ┌─────────────── voyager-sdk (--network=host) ──────┐ │       │
│  │  ai_server.py  :8001                              │ │       │
│  │  Axelera Metis AIPU (PCIe)                        │ │       │
│  │  FFmpeg → RTSP push ──────────────────────────────┼─┘       │
│  └───────────────────────────────────────────────────┘         │
│                                                                │
│  ┌─────────── app-net (Docker bridge) ───────────────┐         │
│  │                                                   │         │
│  │  dashboard-backend  :8000  ←── .env VOYAGER_URL   │         │
│  │  dashboard-frontend :80                           │         │
│  └───────────────────────────────────────────────────┘         │
│                                                                │
└────────────────────────────────────────────────────────────────┘
                           ↑
                    Browser: http://localhost
```

The backend reaches the voyager-sdk via the Pi's LAN IP (detected at startup and written to `.env`). The frontend proxies all API calls through nginx to the backend.