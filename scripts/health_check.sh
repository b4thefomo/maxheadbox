#!/bin/bash
# Check health of all Max Headbox services

PI_HOST="192.168.1.47"
PI_USER="gbade"
PI_ADDR="$PI_USER@$PI_HOST"

echo "======================================"
echo "🏥 MAX HEADBOX HEALTH CHECK"
echo "======================================"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check connectivity
echo "📡 Checking connectivity..."
if ping -c 1 -W 2 "$PI_HOST" > /dev/null 2>&1; then
  echo -e "${GREEN}✅ Pi reachable${NC}"
else
  echo -e "${RED}❌ Cannot reach Pi at $PI_HOST${NC}"
  exit 1
fi
echo ""

# Check services
echo "🔍 Checking services..."
echo ""

# Backend
if curl -s "http://$PI_HOST:4567/" | grep -q "Sinatra is ok"; then
  echo -e "${GREEN}✅ Backend (Port 4567)${NC}"
else
  echo -e "${RED}❌ Backend (Port 4567) - Not responding${NC}"
  echo "   To start: ssh $PI_ADDR 'cd /home/gbade/maxheadbox/backend && bundle exec ruby server_new.rb -o 0.0.0.0 &'"
fi

# Whisper
if curl -s "http://$PI_HOST:8000/" | grep -q "Whisper up and running"; then
  echo -e "${GREEN}✅ Whisper (Port 8000)${NC}"
else
  echo -e "${RED}❌ Whisper (Port 8000) - Not responding${NC}"
  echo "   To start: ssh $PI_ADDR 'cd /home/gbade/maxheadbox && uvicorn backend.audio.whisper_service:app --host 0.0.0.0 --port 8000 &'"
fi

# Ollama
if curl -s "http://$PI_HOST:11434/api/tags" > /dev/null 2>&1; then
  echo -e "${GREEN}✅ Ollama (Port 11434)${NC}"

  # Check if models are loaded
  MODELS=$(curl -s "http://$PI_HOST:11434/api/tags" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | tr '\n' ', ' | sed 's/,$//')
  if [ -n "$MODELS" ]; then
    echo "   Models: $MODELS"
  fi
else
  echo -e "${RED}❌ Ollama (Port 11434) - Not responding${NC}"
  echo "   To start: ssh $PI_ADDR 'sudo systemctl start ollama'"
fi

# Frontend
if curl -s "http://$PI_HOST:4173/" > /dev/null 2>&1; then
  echo -e "${GREEN}✅ Frontend (Port 4173)${NC}"
else
  echo -e "${RED}❌ Frontend (Port 4173) - Not responding${NC}"
  echo "   To start: ssh $PI_ADDR 'cd /home/gbade/maxheadbox && npm run preview &'"
fi

echo ""
echo "======================================"
echo "📊 SYSTEM STATUS"
echo "======================================"
echo ""

# CPU temperature
echo "🌡️  CPU Temperature:"
ssh "$PI_ADDR" "vcgencmd measure_temp" || echo "   Unable to read"

# Uptime
echo ""
echo "⏱️  Uptime:"
ssh "$PI_ADDR" "uptime"

# Disk space
echo ""
echo "💾 Disk Space:"
ssh "$PI_ADDR" "df -h / | tail -1"

# Memory
echo ""
echo "🧠 Memory:"
ssh "$PI_ADDR" "free -h | grep Mem"

echo ""
echo "======================================"
echo "📝 RECENT LOGS (last 10 lines)"
echo "======================================"
echo ""

echo "🔴 Backend:"
ssh "$PI_ADDR" "tail -10 /tmp/backend.log 2>/dev/null || echo '   No logs found'"

echo ""
echo "🐍 Whisper:"
ssh "$PI_ADDR" "tail -10 /tmp/whisper.log 2>/dev/null || echo '   No logs found'"

echo ""
echo "======================================"
echo "✅ Health check complete"
echo "======================================"
echo ""
echo "To view live logs: ./scripts/view_logs.sh"
echo "To deploy latest code: ./scripts/deploy.sh"
