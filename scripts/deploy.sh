#!/bin/bash
# Max Headbox Deployment Script
# Deploys code to Raspberry Pi and verifies services start correctly

set -e  # Exit on error

# Configuration
PI_USER="gbade"
PI_HOST="192.168.1.47"
PI_PATH="/home/gbade/maxheadbox"
PI_ADDR="$PI_USER@$PI_HOST"

echo "======================================"
echo "🚀 MAX HEADBOX DEPLOYMENT"
echo "======================================"
echo ""

# Step 1: Build frontend
echo "📦 Building frontend..."
npm run build
echo "✅ Frontend built"
echo ""

# Step 2: Sync files to Pi (excluding node_modules, .git, etc.)
echo "📤 Syncing files to Raspberry Pi..."
rsync -avz --progress \
  --exclude 'node_modules' \
  --exclude '.git' \
  --exclude 'dist' \
  --exclude '*.log' \
  --exclude '__pycache__' \
  ./ "$PI_ADDR:$PI_PATH/"
echo "✅ Files synced"
echo ""

# Step 3: Rebuild dist on Pi (in case of platform differences)
echo "🔨 Rebuilding on Pi..."
ssh "$PI_ADDR" "cd $PI_PATH && npm run build"
echo "✅ Build complete"
echo ""

# Step 4: Stop existing services
echo "🛑 Stopping existing services..."
ssh "$PI_ADDR" "pkill -f 'ruby server' || true"
ssh "$PI_ADDR" "pkill -f 'uvicorn.*whisper' || true"
ssh "$PI_ADDR" "pkill -f 'npm run preview' || true"
sleep 2
echo "✅ Services stopped"
echo ""

# Step 5: Start services
echo "🔄 Starting services..."

# Start Whisper service
ssh "$PI_ADDR" "cd $PI_PATH && nohup /home/gbade/.local/bin/uvicorn backend.audio.whisper_service:app --host 0.0.0.0 --port 8000 --workers 2 > /tmp/whisper.log 2>&1 &"
sleep 2

# Start backend (use server_new.rb)
ssh "$PI_ADDR" "cd $PI_PATH/backend && nohup /home/gbade/.local/share/gem/ruby/3.3.0/bin/bundle exec ruby server_new.rb -o 0.0.0.0 > /tmp/backend.log 2>&1 &"
sleep 2

# Start frontend
ssh "$PI_ADDR" "cd $PI_PATH && nohup /usr/share/nodejs/corepack/shims/npm run preview > /tmp/vite.log 2>&1 &"
sleep 2

echo "✅ Services started"
echo ""

# Step 6: Verify services are running
echo "🏥 Health check..."
echo ""

# Check Whisper
if curl -s "http://$PI_HOST:8000/" | grep -q "Whisper up and running"; then
  echo "✅ Whisper service: Running"
else
  echo "❌ Whisper service: Failed to start"
  echo "   Check logs: ssh $PI_ADDR 'tail -20 /tmp/whisper.log'"
fi

# Check Backend
if curl -s "http://$PI_HOST:4567/" | grep -q "Sinatra is ok"; then
  echo "✅ Backend service: Running"
else
  echo "❌ Backend service: Failed to start"
  echo "   Check logs: ssh $PI_ADDR 'tail -20 /tmp/backend.log'"
fi

# Check Frontend
if curl -s "http://$PI_HOST:4173/" > /dev/null 2>&1; then
  echo "✅ Frontend service: Running"
else
  echo "❌ Frontend service: Failed to start"
  echo "   Check logs: ssh $PI_ADDR 'tail -20 /tmp/vite.log'"
fi

echo ""
echo "======================================"
echo "📊 Watching logs for 10 seconds..."
echo "======================================"
echo ""

# Watch logs for 10 seconds to verify everything is working
timeout 10 ssh "$PI_ADDR" "
  echo '=== Backend Logs ==='
  tail -5 /tmp/backend.log
  echo ''
  echo '=== Whisper Logs ==='
  tail -5 /tmp/whisper.log
  echo ''
  echo '=== Following backend logs (Ctrl+C to stop) ==='
  tail -f /tmp/backend.log
" || true

echo ""
echo "======================================"
echo "✅ DEPLOYMENT COMPLETE!"
echo "======================================"
echo ""
echo "🌐 Frontend: http://$PI_HOST:4173/"
echo "🔴 Backend:  http://$PI_HOST:4567/"
echo "🐍 Whisper:  http://$PI_HOST:8000/"
echo ""
echo "📊 View logs: ./scripts/view_logs.sh"
echo "🏥 Health check: ./scripts/health_check.sh"
