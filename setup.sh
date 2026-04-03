#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Starter Kit — First-time setup
# Run once before start.sh, or re-run to reconfigure.
# ─────────────────────────────────────────────────────────────────────────────
set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"

echo -e "${CYAN}=== Starter Kit Setup ===${NC}"

# ── 1. Install MediaMTX ───────────────────────────────────────────────────────
if command -v mediamtx &>/dev/null; then
    echo -e "${GREEN}✓ MediaMTX already installed${NC}"
else
    echo -e "${YELLOW}Installing MediaMTX...${NC}"

    MEDIAMTX_VERSION="v1.9.1"
    ARCH=$(uname -m)

    case "$ARCH" in
        aarch64) MEDIAMTX_ARCH="linux_arm64v8" ;;
        armv7l)  MEDIAMTX_ARCH="linux_armv7" ;;
        x86_64)  MEDIAMTX_ARCH="linux_amd64" ;;
        *)
            echo -e "${RED}ERROR: Unsupported architecture: $ARCH${NC}"
            exit 1
            ;;
    esac

    MEDIAMTX_URL="https://github.com/bluenviron/mediamtx/releases/download/${MEDIAMTX_VERSION}/mediamtx_${MEDIAMTX_VERSION}_${MEDIAMTX_ARCH}.tar.gz"
    wget -q --show-progress "$MEDIAMTX_URL" -O /tmp/mediamtx.tar.gz
    sudo tar -xzf /tmp/mediamtx.tar.gz -C /usr/local/bin mediamtx
    sudo chmod +x /usr/local/bin/mediamtx
    rm /tmp/mediamtx.tar.gz
    echo -e "${GREEN}✓ MediaMTX installed${NC}"
fi

# ── 2. Configure MediaMTX ─────────────────────────────────────────────────────
if [ ! -f /etc/mediamtx.yml ]; then
    sudo tee /etc/mediamtx.yml > /dev/null << 'MEDIAMTX_CONF'
logLevel: warn
hlsAddress: :8888
rtspAddress: :8554
readTimeout: 30s
writeTimeout: 30s
readBufferCount: 512
paths:
  live:
    source: publisher
MEDIAMTX_CONF
    echo -e "${GREEN}✓ MediaMTX config created${NC}"
else
    echo -e "${GREEN}✓ MediaMTX config already exists${NC}"
fi

# ── 3. Get voyager-sdk IP via docker exec ─────────────────────────────────────
echo "Detecting voyager-sdk container IP..."

VOYAGER_IP=""

if sudo docker ps --format '{{.Names}}' | grep -q "^voyager-sdk$"; then
    # Exec into the container, run ip addr, pull the first non-loopback inet addr
    VOYAGER_IP=$(sudo docker exec voyager-sdk ip addr show \
        | grep 'inet ' \
        | grep -v '127.0.0.1' \
        | awk '{print $2}' \
        | cut -d/ -f1 \
        | head -1)

    if [ -n "$VOYAGER_IP" ]; then
        echo -e "${GREEN}✓ voyager-sdk IP: ${VOYAGER_IP}${NC}"
    else
        echo -e "${YELLOW}WARNING: Could not parse IP from voyager-sdk — falling back${NC}"
    fi
else
    echo -e "${YELLOW}voyager-sdk not running yet — will be started by start_voyager.sh${NC}"
fi

# Fallback: Pi LAN IP (reachable from any bridge container)
if [ -z "$VOYAGER_IP" ]; then
    VOYAGER_IP=$(hostname -I | awk '{print $1}')
    echo -e "${YELLOW}  Using Pi LAN IP as fallback: ${VOYAGER_IP}${NC}"
fi

# ── 4. Create or update .env ──────────────────────────────────────────────────
if [ -f "$SCRIPT_DIR/.env" ]; then
    # Update VOYAGER_SDK_URL in existing .env
    sed -i "s|^VOYAGER_SDK_URL=.*|VOYAGER_SDK_URL=http://${VOYAGER_IP}:8001|" "$SCRIPT_DIR/.env"
    echo -e "${GREEN}✓ .env updated (VOYAGER_SDK_URL=http://${VOYAGER_IP}:8001)${NC}"
else
    cat > "$SCRIPT_DIR/.env" << ENVEOF
# ── App ───────────────────────────────────────────────────────────────────────
APP_ENV=production
APP_HOST=0.0.0.0
APP_PORT=8000
LOG_LEVEL=info

# ── Data paths (inside container — do not change) ─────────────────────────────
DATA_DIR=data
MODELS_DIR=data/models
RECORDINGS_DIR=data/recordings
EVENTS_DIR=data/events
HLS_DIR=data/hls

# ── HLS streaming ─────────────────────────────────────────────────────────────
HLS_SEGMENT_DURATION=2
HLS_PLAYLIST_SIZE=6

# ── Voyager SDK ───────────────────────────────────────────────────────────────
VOYAGER_SDK_URL=http://${VOYAGER_IP}:8001

# ── CORS ──────────────────────────────────────────────────────────────────────
CORS_ORIGINS=http://localhost
ENVEOF
    echo -e "${GREEN}✓ .env created (VOYAGER_SDK_URL=http://${VOYAGER_IP}:8001)${NC}"
fi

# ── 5. Create data directories ────────────────────────────────────────────────
mkdir -p "$SCRIPT_DIR/data/recordings" \
         "$SCRIPT_DIR/data/uploads" \
         "$SCRIPT_DIR/data/models" \
         "$SCRIPT_DIR/data/hls"
sudo mkdir -p /tmp/hls
echo -e "${GREEN}✓ Data directories ready${NC}"

# ── 6. USB camera detection — update docker-compose.yml ──────────────────────
echo ""
echo "Checking for USB camera..."

if [ ! -f "$COMPOSE_FILE" ]; then
    echo -e "${RED}ERROR: docker-compose.yml not found at $COMPOSE_FILE${NC}"
    exit 1
fi

if [ -e /dev/video0 ]; then
    echo -e "${GREEN}✓ USB camera detected at /dev/video0${NC}"

    # Uncomment devices block and device line if they are commented out
    sed -i 's|#\s*devices:|    devices:|' "$COMPOSE_FILE"
    sed -i 's|#\s*- /dev/video0:/dev/video0|      - /dev/video0:/dev/video0|' "$COMPOSE_FILE"

    echo -e "${GREEN}✓ docker-compose.yml — USB camera enabled${NC}"
else
    echo -e ""
    echo -e "${YELLOW}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}│  ⚠  No USB camera detected at /dev/video0                │${NC}"
    echo -e "${YELLOW}│                                                          │${NC}"
    echo -e "${YELLOW}│  USB camera features will be blocked in the dashboard.   │${NC}"
    echo -e "${YELLOW}│                                                          │${NC}"
    echo -e "${YELLOW}│  To enable USB camera access:                            │${NC}"
    echo -e "${YELLOW}│    1. Plug in your USB camera                            │${NC}"
    echo -e "${YELLOW}│    2. Run  ./start.sh  again                             │${NC}"
    echo -e "${YELLOW}│                                                          │${NC}"
    echo -e "${YELLOW}└──────────────────────────────────────────────────────────┘${NC}"
    echo -e ""

    # Comment out devices block and device line if they are active
    sed -i 's|^\(\s*\)devices:|\1# devices:|' "$COMPOSE_FILE"
    sed -i 's|^\(\s*\)- /dev/video0:/dev/video0|\1#- /dev/video0:/dev/video0|' "$COMPOSE_FILE"

    echo -e "${YELLOW}  docker-compose.yml — USB device lines disabled${NC}"
fi

echo ""
echo -e "${GREEN}=== Setup complete ===${NC}"
echo "Run ./start.sh to start everything."