#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Starter Kit — First-time setup
# ─────────────────────────────────────────────────────────────────────────────
set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

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

# ── 3. Get voyager-sdk IP and build .env ──────────────────────────────────────
echo "Detecting voyager-sdk IP..."

VOYAGER_IP=""

# Try to exec into voyager-sdk container and get its IP
if sudo docker ps --format '{{.Names}}' | grep -q "^voyager-sdk$"; then
    VOYAGER_IP=$(sudo docker exec voyager-sdk hostname -I 2>/dev/null | awk '{print $1}')
    echo -e "${GREEN}✓ Found voyager-sdk container IP: ${VOYAGER_IP}${NC}"
else
    # voyager-sdk uses host network — fall back to docker bridge gateway
    VOYAGER_IP=$(ip route show | grep 'docker0' | awk '{print $9}' 2>/dev/null)
    if [ -z "$VOYAGER_IP" ]; then
        # last resort hardcoded default
        VOYAGER_IP="172.17.0.1"
    fi
    echo -e "${YELLOW}voyager-sdk not running yet — using bridge IP: ${VOYAGER_IP}${NC}"
    echo -e "${YELLOW}  (start_voyager.sh will be called by start.sh after this)${NC}"
fi

# ── 4. Create .env ────────────────────────────────────────────────────────────
if [ -f .env ]; then
    echo -e "${GREEN}✓ .env already exists — skipping${NC}"
else
    cat > .env << ENVEOF
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
mkdir -p data/recordings data/uploads data/models data/hls
sudo mkdir -p /tmp/hls
echo -e "${GREEN}✓ Data directories ready${NC}"

# ── 6. Check video device ─────────────────────────────────────────────────────
if [ ! -e /dev/video0 ]; then
    echo -e "${YELLOW}WARNING: /dev/video0 not found — USB camera may not be connected${NC}"
else
    echo -e "${GREEN}✓ /dev/video0 found${NC}"
fi

echo ""
echo -e "${GREEN}=== Setup complete ===${NC}"
echo "Run ./start.sh to start everything."