#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Starter Kit — stop.sh
# Gracefully stops all services
# ─────────────────────────────────────────────────────────────────────────────

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo -e "${CYAN}=== Stopping Starter Kit ===${NC}"

# Stop inference sessions
echo "Stopping voyager inference sessions..."
docker exec voyager-sdk curl -s http://localhost:8001/inference/status \
    | python3 -c "
import sys, json, urllib.request
try:
    sessions = json.load(sys.stdin).get('sessions', [])
    for s in sessions:
        req = urllib.request.Request(
            'http://localhost:8001/inference/stop',
            data=json.dumps({'run_id': s['run_id']}).encode(),
            headers={'Content-Type': 'application/json'},
            method='POST'
        )
        urllib.request.urlopen(req, timeout=5)
        print(f'  stopped: {s[\"run_id\"]}')
except Exception as e:
    print(f'  (skipped: {e})')
" 2>/dev/null || true

# Stop ai_server
echo "Stopping voyager-sdk ai_server..."
docker exec voyager-sdk pkill -f ai_server.py 2>/dev/null || true
echo -e "${GREEN}✓ voyager-sdk stopped${NC}"

# Stop dashboard containers
echo "Stopping dashboard containers..."
cd "$SCRIPT_DIR"
sudo docker compose down --remove-orphans 2>/dev/null || true
echo -e "${GREEN}✓ Containers stopped${NC}"

# Stop MediaMTX
echo "Stopping MediaMTX..."
pkill -f mediamtx 2>/dev/null || true
echo -e "${GREEN}✓ MediaMTX stopped${NC}"

echo ""
echo -e "${GREEN}=== All services stopped ===${NC}"