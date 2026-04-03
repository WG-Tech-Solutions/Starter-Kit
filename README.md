# WGtech AI Starter Pack — Dashboard

<p align="justify">
This Starter Kit is designed to empower university students, researchers, and enthusiasts to explore Edge AI through a comprehensive platform for computer vision development and deployment. Built with industry-standard components and advanced AI acceleration technologies, it enables users to run, compare, and analyze Vision AI models in real-world scenarios, supporting academic projects, experimentation, and applied research.
</p>

## 🚀 Getting Started — Follow These Steps

### Step 1 — Clone this repo

Run this on your **desktop or laptop** (not the Pi yet):

```bash
git clone https://github.com/WG-Tech-Solutions/Starter-Kit.git
cd Starter-Kit
```

Or download and extract the ZIP from GitHub if you don't have git installed.

### Step 2 — Open aistarterpack.html

Inside the cloned folder you will find `aistarterpack.html`. Open it in a browser:

- **Windows / macOS:** double-click `aistarterpack.html`
- **Linux:** `xdg-open aistarterpack.html`

That guide walks you through everything on the Raspberry Pi — flashing the OS, enabling PCIe Gen3, installing Docker, installing the Axelera Metis driver, and confirming AI inference is working on the AIPU. It takes 20–50 minutes.

**Do not run any scripts in this repo until you have finished the HTML guide.** The scripts depend on the `voyager-sdk` container and Axelera driver that the guide sets up — they will fail if those are not in place.

### Step 3 — Come back here

Return to this README after you have:
- Completed all 10 sections of `aistarterpack.html`
- Seen FPS output from `./inference.py yolov5s-v7-coco media/traffic1_1080p.mp4` inside the `voyager-sdk` container

Then continue to the prerequisites section below.

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
Starter-Kit/
├── aistarterpack.html    ← hardware setup guide — start here
├── README.md             ← this file — deployment and setup
├── userguide.md          ← how to use the dashboard after setup
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

## Using the dashboard

Once the dashboard is running, refer to **`userguide.md`** in this repo for a full walkthrough of the application — connecting cameras, running inference, managing recordings, uploading custom models, and everything else the dashboard can do.

Open it in any markdown viewer, or read it directly on GitHub alongside this README.

---

## First-time setup

### Step 1 — Make scripts executable

Open a terminal on the Pi and navigate to this folder:

```bash
cd ~/Starter-Kit        # or wherever you placed this folder
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
3. **Starts the dashboard** — runs `docker compose up`, waits for the backend health check to pass

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