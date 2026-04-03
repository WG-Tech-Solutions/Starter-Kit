# WGtech AI Starter Pack — Dashboard

---

## ⚠️ Start here — read before touching anything

**This repo contains two things:**

| File | What it is | Do this first |
|---|---|---|
| `aistarterpack.html` | Hardware setup guide | **Yes — complete this first** |
| Everything else | Dashboard scripts | Only after the guide is done |

**Open `aistarterpack.html` in a browser on your desktop or laptop:**

```
Right-click aistarterpack.html → Open with → your browser
```

That guide takes you from a blank microSD card all the way through flashing Raspberry Pi OS, installing the Axelera Metis driver, setting up Docker, and confirming AI inference is working on the AIPU. It takes 20–50 minutes.

**Come back to this README only after you have:**
1. Completed every section of `aistarterpack.html` (Sections 1–10)
2. Confirmed inference is running — you saw FPS output from `./inference.py yolov5s-v7-coco media/traffic1_1080p.mp4` inside the `voyager-sdk` container

If you skip the HTML guide and run these scripts first, they will fail — the `voyager-sdk` container and Axelera driver that these scripts depend on will not exist yet.

---

## Prerequisites — verify these before running start.sh

Once you have finished `aistarterpack.html`, confirm each of the following. If any fail, go back to the relevant section in the HTML guide.

**1. OS is up to date**
```bash
cat /etc/os-release | grep PRETTY
```
Should show Raspberry Pi OS (Debian) — 64-bit.

**2. PCIe Gen3 is enabled**
```bash
sudo cat /sys/bus/pci/devices/0001:01:00.0/current_link_speed
```
Should show `8.0 GT/s PCIe`. If not, re-run Section 5 of the HTML guide.

**3. Docker is working**
```bash
docker run hello-world
```
Should print `Hello from Docker!`.

**4. Axelera driver is installed**
```bash
dkms status
lspci | grep -i axelera
```
`dkms status` should show `metis/1.5.3 ... installed`. `lspci` should show the Metis card.

**5. voyager-sdk container exists**
```bash
docker ps -a | grep voyager-sdk
```
Should show the container (status can be Exited — that is fine).

**6. Inference was confirmed working**

You should have already run this inside the container and seen FPS output:
```bash
./inference.py yolov5s-v7-coco media/traffic1_1080p.mp4
```

If all six pass, continue to the next section.

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