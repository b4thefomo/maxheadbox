#!/bin/bash
# View all Max Headbox logs in real-time with color coding

PI_USER="gbade"
PI_HOST="192.168.1.47"
PI_ADDR="$PI_USER@$PI_HOST"

echo "======================================"
echo "📊 MAX HEADBOX LIVE LOGS"
echo "======================================"
echo ""
echo "Ctrl+C to stop"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Tail all log files and prefix with service name
ssh "$PI_ADDR" "
  # Function to prefix and color-code logs
  tail -f \
    /tmp/backend.log \
    /tmp/whisper.log \
    /tmp/vite.log \
    2>/dev/null | \
  while IFS= read -r line; do
    # Detect which file the line came from based on content
    if echo \"\$line\" | grep -q '\[Recording\]\|\[Transcription\]\|[LLM]\|\[WebSocket\]'; then
      echo -e \"\033[0;31m[BACKEND]\033[0m \$line\"
    elif echo \"\$line\" | grep -q 'Whisper\|faster-whisper\|transcribe'; then
      echo -e \"\033[0;32m[WHISPER]\033[0m \$line\"
    elif echo \"\$line\" | grep -q 'vite\|preview'; then
      echo -e \"\033[0;34m[VITE]\033[0m \$line\"
    else
      echo \"\$line\"
    fi
  done
" || {
  echo ""
  echo "❌ Could not connect to Pi"
  echo "   Make sure services are running: ./scripts/deploy.sh"
}
