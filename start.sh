#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Starter Kit — Main entry point
# Starts Voyager SDK, runs setup, then brings up the dashboard containers.
# ─────────────────────────────────────────────────────────────────────────────
set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo -e "${CYAN}"
echo "  ██╗    ██╗ ██████╗ ████████╗███████╗ ██████╗██╗  ██╗"
echo "  ██║    ██║██╔════╝ ╚══██╔══╝██╔════╝██╔════╝██║  ██║"
echo "  ██║ █╗ ██║██║  ███╗   ██║   █████╗  ██║     ███████║"
echo "  ██║███╗██║██║   ██║   ██║   ██╔══╝  ██║     ██╔══██║"
echo "  ╚███╔███╔╝╚██████╔╝   ██║   ███████╗╚██████╗██║  ██║"
echo "   ╚══╝╚══╝  ╚═════╝    ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝"
echo -e "${NC}"
echo -e "${CYAN}  AI Starter Pack — Dashboard Launcher${NC}"
echo ""

# ── Step 1: Start Voyager SDK + MediaMTX ─────────────────────────────────────
echo -e "${CYAN}[1/3] Starting Voyager SDK...${NC}"
bash "$SCRIPT_DIR/start_voyager.sh"
echo ""

# ── Step 2: Run setup (detect camera, build .env, create dirs) ────────────────
echo -e "${CYAN}[2/3] Running setup...${NC}"
bash "$SCRIPT_DIR/setup.sh"
echo ""

# ── Step 3: Bring up dashboard containers ─────────────────────────────────────
echo -e "${CYAN}[3/3] Starting dashboard containers...${NC}"
cd "$SCRIPT_DIR"
sudo docker compose down --remove-orphans 2>/dev/null || true
sudo docker compose up -d
echo ""

# ── Health check ──────────────────────────────────────────────────────────────
echo "Waiting for backend to become healthy..."
MAX_WAIT=60
ELAPSED=0
until sudo docker inspect --format='{{.State.Health.Status}}' dashboard-backend 2>/dev/null | grep -q "healthy"; do
    if [ "$ELAPSED" -ge "$MAX_WAIT" ]; then
        echo -e "${RED}ERROR: Backend did not become healthy within ${MAX_WAIT}s${NC}"
        echo "  Check logs: sudo docker logs dashboard-backend"
        exit 1
    fi
    sleep 3
    ELAPSED=$((ELAPSED + 3))
    echo -n "."
done
echo ""
echo -e "${GREEN}✓ Backend healthy${NC}"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓  WGtech AI Dashboard is running                      ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Dashboard:      http://localhost                        ║${NC}"
echo -e "${GREEN}║  Backend API:    http://localhost/api                    ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Useful commands:                                        ║${NC}"
echo -e "${GREEN}║  Voyager logs:  docker exec voyager-sdk tail -f          ║${NC}"
echo -e "${GREEN}║                          /tmp/ai_server.log              ║${NC}"
echo -e "${GREEN}║  Backend logs:  sudo docker logs -f dashboard-backend    ║${NC}"
echo -e "${GREEN}║  Stop all:      bash stop.sh                             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""