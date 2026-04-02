#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Starter Kit — First-time setup
# Run this once before start.sh
# ─────────────────────────────────────────────────────────────────────────────
set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== Starter Kit Setup ===${NC}"

# ── 1. Create .env from example ───────────────────────────────────────────────
if [ -f .env ]; then
    echo -e "${GREEN}✓ .env already exists — skipping${NC}"
else
    if [ ! -f .env.example ]; then
        echo -e "${RED}ERROR: .env.example not found. Are you in the right directory?${NC}"
        exit 1
    fi
    cp .env.example .env
    echo -e "${GREEN}✓ Created .env from .env.example${NC}"
    echo -e "${YELLOW}  Edit .env if you need to change any settings${NC}"
fi

# ── 2. Create data directories ────────────────────────────────────────────────
echo "Creating data directories..."
mkdir -p data/recordings data/uploads data/models data/hls
sudo mkdir -p /tmp/hls
echo -e "${GREEN}✓ Data directories ready${NC}"

# ── 3. Check Docker is installed ─────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    echo -e "${RED}ERROR: Docker not found. Please install Docker first.${NC}"
    echo "  https://docs.docker.com/engine/install/"
    exit 1
fi
echo -e "${GREEN}✓ Docker found${NC}"

# ── 4. Check video device ─────────────────────────────────────────────────────
if [ ! -e /dev/video0 ]; then
    echo -e "${YELLOW}WARNING: /dev/video0 not found — USB camera may not be connected${NC}"
else
    echo -e "${GREEN}✓ /dev/video0 found${NC}"
fi

echo ""
echo -e "${GREEN}=== Setup complete ===${NC}"
echo "Run ./start.sh to start everything."