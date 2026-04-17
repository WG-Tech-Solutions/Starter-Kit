# WGtech AI Starter Pack — Dashboard

<p align="justify">
This Starter Kit is designed to empower university students, researchers, and enthusiasts to explore Edge AI through a comprehensive platform for computer vision development and deployment. Built with industry-standard components and advanced AI acceleration technologies, it enables users to run, compare, and analyze Vision AI models in real-world scenarios, supporting academic projects, experimentation, and applied research.
</p>

---

## 🚀 Getting Started — Follow These Steps

### Step 1 — Clone this repo

Run this on your **Desktop/Laptop** terminal:

```bash
git clone https://github.com/WG-Tech-Solutions/Starter-Kit.git
cd Starter-Kit
```

### Step 2 — Open Aistarterpack.html

Inside the cloned folder you will find `Aistarterpack.html`. Open it in a browser on your desktop or laptop — it walks you through everything on the Raspberry Pi:

- Flashing the OS
- Enabling PCIe Gen3
- Installing Docker
- Installing the Axelera Metis driver
- Confirming AI inference is working on the AIPU

This takes a total time of 2-4+ hours (Active set up time: 20-50 mins). **Do not run any scripts in this repo until you have finished the HTML guide.**

### Step 3 — Come back here

Return after you have:
- Completed all sections of [Aistarterpack.html](Aistarterpack.html)
- Seen FPS output from `./inference.py yolov5s-v7-coco media/traffic1_1080p.mp4` inside the voyager-sdk container

---

## Prerequisites — verify before running start.sh

Run In Host (Raspberry Pi 5) terminal -

**1. OS is 64-bit**
```bash
cat /etc/os-release | grep PRETTY
```

**2. PCIe Gen3 enabled**
```bash
sudo cat /sys/bus/pci/devices/0001:01:00.0/current_link_speed
# Should show: 8.0 GT/s PCIe
```

**3. Docker working**
```bash
docker run hello-world
```

**4. Axelera driver installed**
```bash
dkms status
lspci | grep -i axelera
```

**5. voyager-sdk container exists**
```bash
docker ps -a | grep voyager-sdk
```

**6. Inference confirmed working** — you ran `./inference.py` previously in the Voyager-sdk container terminal and saw FPS output.

---

## File overview

```
Starter-Kit/
├── Aistarterpack.html    ← hardware setup guide — start here
├── README.md             ← this file
├── userguide.md          ← how to use the dashboard after setup
├── start.sh              ← main entry point — run this every time
├── stop.sh               ← cleanly stops all services
├── start_voyager.sh      ← starts voyager-sdk container + MediaMTX
├── setup.sh              ← installs MediaMTX, builds .env, handles USB camera
├── docker-compose.yml    ← frontend + backend containers
├── voyager-service/
│   ├── ai_server.py      ← FastAPI server inside voyager-sdk
│   ├── ai_inference.py   ← inference session management
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

```bash
cd ~/Starter-Kit
chmod +x start.sh stop.sh start_voyager.sh setup.sh
```

### Step 2 — Set xhost permissions

Required every reboot:

```bash
xhost +local:root
xhost +local:docker
```

### Step 3 — Load the kernel module

```bash
sudo modprobe metis
lsmod | grep metis   # should show metis in output
```

### Step 4 — (Optional) Connect USB camera

Plug it in **before** running `start.sh`. The setup script detects it automatically. If you plug it in later, just re-run `./start.sh`.

### Step 5 — Run start.sh

```bash
./start.sh
```

This does four things in order:

1. **setup.sh** — installs MediaMTX (first time only), creates `.env`, sets up data directories, detects USB camera
2. **start_voyager.sh** — starts MediaMTX, starts the voyager-sdk container, copies service files, detects container IP, updates `.env`, starts `ai_server.py`
3. **docker compose up** — pulls and starts the frontend and backend containers
4. **Health check** — waits for the backend to report healthy

When it finishes you will see:

```
╔══════════════════════════════════════════════════════════╗
║  ✓  WGtech AI Dashboard is running                      ║
╠══════════════════════════════════════════════════════════╣
║  Dashboard:      http://localhost                        ║
║  Backend API:    http://localhost/api                    ║
╚══════════════════════════════════════════════════════════╝
```

Open a browser and go to **http://localhost**. 

Before exploring the dashboard, it is recommended to read [USER_GUIDE.md](USER_GUIDE.md) to understand the application's features, usage, and FAQs.

The [videos](videos/) folder contains sample videos that can be used as input for selected object classes. Refer to [videos/VIDEOS_GUIDE.md](videos/VIDEOS_GUIDE.md) for details on the supported classes for model deployment.

---

## Every boot — what to run

```bash
sudo modprobe metis
xhost +local:root
xhost +local:docker
./start.sh
```

---

## USB camera behaviour

[setup.sh](setup.sh) checks for `/dev/video0` on every run and automatically updates [docker-compose.yml](docker-compose.yml):

| Camera state | What happens |
|---|---|
| Plugged in before `./start.sh` | Detected, passed through to backend, full USB features available |
| Not plugged in | Warning printed, USB features disabled in dashboard |
| Plugged in after containers started | Run `./start.sh` again |

> **Do not edit the `devices:` block in [docker-compose.yml](docker-compose.yml) manually** — it is managed by [setup.sh](setup.sh).

---

## Stopping everything

```bash
./stop.sh
```

This stops inference sessions, `ai_server.py`, the dashboard containers, and MediaMTX in the correct order.

---

## Useful commands

```bash
# Dashboard backend logs
sudo docker logs -f dashboard-backend

# Voyager SDK / inference server logs
docker exec voyager-sdk tail -f /tmp/ai_server.log

# MediaMTX logs
tail -f ~/Starter-Kit/mediamtx.log

# Check running containers
sudo docker ps

# Check voyager-sdk health
docker exec voyager-sdk curl -s http://localhost:8001/health

# Restart everything
./start.sh
```

---

## Troubleshooting

### Dashboard won't load at http://localhost

```bash
sudo docker ps | grep frontend
sudo docker logs dashboard-frontend
```

### Backend keeps restarting

```bash
sudo docker logs dashboard-backend
cat .env | grep VOYAGER_SDK_URL
curl http://<that-ip>:8001/health
```

If the health check fails, re-run `./start.sh` — it re-detects the IP automatically.

### voyager-sdk health check fails

```bash
docker exec voyager-sdk tail -40 /tmp/ai_server.log
```

If you see AIPU/device errors, reboot the Pi fully (power cycle, not just `reboot`), then:

```bash
sudo modprobe metis
xhost +local:root
xhost +local:docker
./start.sh
```

### axdevice shows no devices

```bash
lspci | grep -i axelera   # card should appear here
sudo modprobe metis
lsmod | grep metis
```

If the card doesn't appear in `lspci`, power cycle the Pi and check physical connections per the setup guide.

### USB camera detected but no video

```bash
sudo docker inspect dashboard-backend | grep -A5 Devices
fuser /dev/video0   # check if locked by another process
```

Re-run `./start.sh` with the camera plugged in if the devices block is empty.

---

## For More Information and References

Raspberry Pi Documentation: https://www.raspberrypi.com/documentation/

Axelera's Voyager SDK repository: https://github.com/axelera-ai-hub/voyager-sdk