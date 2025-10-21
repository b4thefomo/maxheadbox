# Max Headbox Development Scripts

These scripts implement the rapid iteration development lifecycle documented in `../DEVELOPMENT_LIFECYCLE.md`.

## Quick Reference

```bash
# Deploy code to Raspberry Pi
./scripts/deploy.sh

# Check if all services are running
./scripts/health_check.sh

# View real-time logs from all services
./scripts/view_logs.sh
```

## Scripts

### `deploy.sh` - Deploy to Raspberry Pi

**Purpose**: Build frontend, sync code to Pi, restart services, verify deployment

**Usage**:
```bash
./scripts/deploy.sh
```

**What it does**:
1. Builds frontend (`npm run build`)
2. Syncs code to Pi via rsync (excludes node_modules, .git)
3. Rebuilds on Pi (in case of platform differences)
4. Stops existing services
5. Starts all services (Whisper, Backend, Frontend)
6. Runs health checks
7. Shows last 10 seconds of logs

**Time**: ~60 seconds for full deployment

**Output**:
```
======================================
🚀 MAX HEADBOX DEPLOYMENT
======================================

📦 Building frontend...
✅ Frontend built

📤 Syncing files to Raspberry Pi...
✅ Files synced

🔄 Starting services...
✅ Services started

🏥 Health check...
✅ Whisper service: Running
✅ Backend service: Running
✅ Frontend service: Running

✅ DEPLOYMENT COMPLETE!

🌐 Frontend: http://192.168.1.47:4173/
🔴 Backend:  http://192.168.1.47:4567/
🐍 Whisper:  http://192.168.1.47:8000/
```

---

### `health_check.sh` - Service Health Check

**Purpose**: Verify all services are running and healthy

**Usage**:
```bash
./scripts/health_check.sh
```

**What it checks**:
- Network connectivity to Pi
- Backend service (port 4567)
- Whisper service (port 8000)
- Ollama service (port 11434)
- Frontend service (port 4173)
- CPU temperature
- System uptime
- Disk space
- Memory usage
- Recent logs from each service

**Time**: ~5 seconds

**Output**:
```
======================================
🏥 MAX HEADBOX HEALTH CHECK
======================================

📡 Checking connectivity...
✅ Pi reachable

🔍 Checking services...

✅ Backend (Port 4567)
✅ Whisper (Port 8000)
✅ Ollama (Port 11434)
   Models: gemma3:1b, qwen3:1.7b
✅ Frontend (Port 4173)

======================================
📊 SYSTEM STATUS
======================================

🌡️  CPU Temperature:
temp=45.0'C

⏱️  Uptime:
 10:30:15 up 2 days, 14:23,  1 user,  load average: 0.52, 0.58, 0.59

💾 Disk Space:
/dev/mmcblk0p2   29G   12G   16G  43% /

🧠 Memory:
Mem:           3.7Gi       1.2Gi       1.8Gi        52Mi       695Mi       2.2Gi
```

---

### `view_logs.sh` - Real-Time Log Viewer

**Purpose**: View logs from all services in real-time with color coding

**Usage**:
```bash
./scripts/view_logs.sh
```

**What it shows**:
- Backend logs (red prefix: `[BACKEND]`)
- Whisper logs (green prefix: `[WHISPER]`)
- Vite logs (blue prefix: `[VITE]`)
- Real-time updates as logs are written

**Controls**:
- `Ctrl+C` to stop

**Example Output**:
```
======================================
📊 MAX HEADBOX LIVE LOGS
======================================

Ctrl+C to stop

[BACKEND] [Recording] 🎤 Starting new recording...
[BACKEND] [Recording] ✅ Started (PID: 12345)
[BACKEND] [Recording] ⏹️  Finished after 10.09s
[WHISPER] [INFO] Transcription request received
[WHISPER] [INFO] Processing /dev/shm/recording.wav
[BACKEND] [Transcription] 📝 Calling Whisper service...
[BACKEND] [Transcription] ✅ Completed in 2.04s → "Hello there."
[BACKEND] [WebSocket] 📤 Sent recording_finished event to 1 client(s)
[BACKEND] [LLM] 💬 Calling Ollama (model: gemma3:1b)
[BACKEND] [LLM] ✅ Response received in 3.21s (156 chars)
```

---

## Development Workflow

### 1. Make Code Changes (on Mac)

Edit files in VS Code or your preferred editor:
```bash
# Edit backend
vim backend/audio/recorder.rb

# Edit frontend
vim src/SimpleApp.jsx
```

### 2. Deploy to Pi

```bash
./scripts/deploy.sh
```

This builds, syncs, and restarts everything.

### 3. Monitor Logs

In a separate terminal:
```bash
./scripts/view_logs.sh
```

Watch for errors or unexpected behavior.

### 4. Test on Pi

Open browser to `http://192.168.1.47:4173/` and test your changes.

### 5. Debug Issues

If something's wrong:

```bash
# Check what's running
./scripts/health_check.sh

# See recent logs
ssh gbade@192.168.1.47 'tail -50 /tmp/backend.log'

# See specific component logs
ssh gbade@192.168.1.47 'grep "[Recording]" /tmp/backend.log'
```

### 6. Iterate

Make fixes, run `./scripts/deploy.sh` again.

**Typical iteration time**: 1-2 minutes from code change to testing.

---

## Troubleshooting

### "Services failed to start"

```bash
# Check which service failed
./scripts/health_check.sh

# View its logs
ssh gbade@192.168.1.47 'tail -50 /tmp/backend.log'
ssh gbade@192.168.1.47 'tail -50 /tmp/whisper.log'
```

### "Can't connect to Pi"

```bash
# Test connectivity
ping 192.168.1.47

# Test SSH
ssh gbade@192.168.1.47 'echo "Connected!"'
```

### "Logs show errors"

```bash
# View full logs with context
./scripts/view_logs.sh

# Search for specific errors
ssh gbade@192.168.1.47 'grep "❌" /tmp/backend.log'
```

### "Service won't stop"

```bash
# Kill services manually
ssh gbade@192.168.1.47 'pkill -f "ruby server"'
ssh gbade@192.168.1.47 'pkill -f "uvicorn.*whisper"'
ssh gbade@192.168.1.47 'pkill -f "npm run preview"'

# Then redeploy
./scripts/deploy.sh
```

---

## Advanced Usage

### Deploy only backend

```bash
# Sync backend files only
rsync -avz backend/ gbade@192.168.1.47:/home/gbade/maxheadbox/backend/

# Restart backend
ssh gbade@192.168.1.47 'pkill -f "ruby server" && cd /home/gbade/maxheadbox/backend && bundle exec ruby server_new.rb -o 0.0.0.0 > /tmp/backend.log 2>&1 &'
```

### Deploy only frontend

```bash
# Build and sync
npm run build
rsync -avz dist/ gbade@192.168.1.47:/home/gbade/maxheadbox/dist/

# Restart frontend
ssh gbade@192.168.1.47 'pkill -f "npm run preview" && cd /home/gbade/maxheadbox && npm run preview > /tmp/vite.log 2>&1 &'
```

### View specific component logs

```bash
# Only Recording logs
ssh gbade@192.168.1.47 'grep "\[Recording\]" /tmp/backend.log'

# Only LLM logs
ssh gbade@192.168.1.47 'grep "\[LLM\]" /tmp/backend.log'

# Only errors
ssh gbade@192.168.1.47 'grep "❌" /tmp/backend.log'

# Performance metrics
ssh gbade@192.168.1.47 'grep "Completed in" /tmp/backend.log'
```

---

## Future Enhancements

- [ ] Add `start_services.sh` - Start without deploying
- [ ] Add `stop_services.sh` - Stop all services
- [ ] Add `generate_metrics.sh` - Extract performance metrics from logs
- [ ] Add unified logging to single file `/tmp/maxheadbox.log`
- [ ] Add log rotation configuration
- [ ] Add remote frontend logging (browser → backend)

---

## See Also

- `../DEVELOPMENT_LIFECYCLE.md` - Complete guide to development workflow
- `../MODULAR_ARCHITECTURE.md` - Architecture documentation
- `../SYSTEM_ARCHITECTURE.md` - System architecture diagrams
