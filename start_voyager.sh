#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Starter Kit — start_voyager.sh
# Starts MediaMTX + voyager-sdk container
# ─────────────────────────────────────────────────────────────────────────────
set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

CONTAINER="voyager-sdk"
DEST="/home/voyager-sdk"
VENV="$DEST/venv"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICE_DIR="$SCRIPT_DIR/voyager-service"
MEDIAMTX_LOG="$SCRIPT_DIR/mediamtx.log"

echo -e "${CYAN}=== Starting Voyager SDK ===${NC}"

# ── 1. Disable core dumps ─────────────────────────────────────────────────────
ulimit -c 0
sudo sysctl -w kernel.core_pattern=/dev/null > /dev/null 2>&1 || true

# ── 2. Start MediaMTX ─────────────────────────────────────────────────────────
echo "Starting MediaMTX..."
pkill -f mediamtx 2>/dev/null || true
sleep 1

nohup mediamtx /etc/mediamtx.yml > "$MEDIAMTX_LOG" 2>&1 &
sleep 2

if ss -tlnp | grep -q ':8554' || ss -tlnp | grep -q ':8888'; then
    echo -e "${GREEN}✓ MediaMTX running (RTSP :8554, HLS :8888)${NC}"
else
    echo -e "${RED}ERROR: MediaMTX failed to start — check $MEDIAMTX_LOG${NC}"
    exit 1
fi

# ── 3. Check voyager-sdk container exists ─────────────────────────────────────
echo "Checking voyager-sdk container..."
if ! docker inspect "$CONTAINER" > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Container '$CONTAINER' not found.${NC}"
    echo "  Complete the aistarterpack.html guide first."
    exit 1
fi
echo -e "${GREEN}✓ Container found${NC}"

# ── 4. Start container ────────────────────────────────────────────────────────
echo "Starting $CONTAINER..."
docker start "$CONTAINER"
sleep 2
echo -e "${GREEN}✓ Container started${NC}"

# ── 5. Copy service files ─────────────────────────────────────────────────────
echo "Copying voyager-service files..."
for f in ai_server.py ai_inference.py wginference.py; do
    if [ ! -f "$SERVICE_DIR/$f" ]; then
        echo -e "${RED}ERROR: $SERVICE_DIR/$f not found${NC}"
        exit 1
    fi
    docker cp "$SERVICE_DIR/$f" "$CONTAINER:$DEST/$f"
    echo "  copied $f"
done
echo -e "${GREEN}✓ Service files copied${NC}"

# ── 6. Install system dependencies ───────────────────────────────────────────
echo "Checking system dependencies..."
docker exec -u root "$CONTAINER" bash -c "
    which ffmpeg > /dev/null 2>&1 || (apt-get update -qq && apt-get install -y -q ffmpeg)
    which pgrep  > /dev/null 2>&1 || (apt-get install -y -q procps)
" && echo -e "${GREEN}✓ System deps ok${NC}"

# ── 7. Install Python dependencies ───────────────────────────────────────────
echo "Installing Python dependencies..."
docker exec "$CONTAINER" bash -c "
    source $VENV/bin/activate &&
    pip install --quiet fastapi uvicorn httpx pyyaml psutil
" && echo -e "${GREEN}✓ Python deps ok${NC}"

# ── 8. Kill stale processes and free AIPU cores ───────────────────────────────
echo "Clearing stale processes and freeing AIPU..."
docker exec "$CONTAINER" bash -c "
    pkill -9 -f ai_server.py          2>/dev/null || true
    pkill -9 -f 'python3.*inference'   2>/dev/null || true
    pkill -9 -f wginference            2>/dev/null || true
    sleep 2
" 2>/dev/null || true
echo -e "${GREEN}✓ Processes cleared${NC}"

# ── 9. Set up HLS directories ─────────────────────────────────────────────────
echo "Setting up HLS directories..."
sudo mkdir -p /tmp/hls
for slot in 2 3 4 5; do
    sudo mkdir -p /tmp/hls/slot-$slot
done
docker exec "$CONTAINER" bash -c "
    mkdir -p /tmp/hls/slot-2 /tmp/hls/slot-3 /tmp/hls/slot-4 /tmp/hls/slot-5
"
echo -e "${GREEN}✓ HLS dirs ready${NC}"

# ── 10. Start ai_server.py ────────────────────────────────────────────────────
echo "Starting ai_server.py..."
docker exec "$CONTAINER" bash -c "
    source $VENV/bin/activate
    cd $DEST
    export HLS_ROOT='/tmp/hls'
    export RTSP_URL='rtsp://127.0.0.1:8554/live'
    nohup python3 -u ai_server.py > /tmp/ai_server.log 2>&1 &
    disown
    echo \$! > /tmp/ai_server.pid
"
sleep 3

# ── 11. Verify ────────────────────────────────────────────────────────────────
echo "Verifying voyager-sdk health..."
if docker exec "$CONTAINER" curl -sf http://localhost:8001/health > /dev/null; then
    echo -e "${GREEN}✓ voyager-sdk is UP at http://localhost:8001${NC}"
else
    echo -e "${RED}FAILED. Last 20 lines of log:${NC}"
    docker exec "$CONTAINER" tail -20 /tmp/ai_server.log 2>/dev/null || echo "no log file"
    exit 1
fi

echo ""
echo -e "${GREEN}=== Voyager SDK running ===${NC}"
echo -e "  Voyager logs:  docker exec $CONTAINER tail -f /tmp/ai_server.log"
echo -e "  MediaMTX logs: tail -f $MEDIAMTX_LOG"