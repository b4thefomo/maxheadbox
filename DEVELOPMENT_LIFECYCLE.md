# Development Lifecycle & Debugging Architecture

## Philosophy: Optimize for Rapid Iteration

The Max Headbox architecture is designed around one core principle: **Fast feedback loops through comprehensive logging and clean debugging data.**

When developing on embedded hardware (Raspberry Pi), you cannot rely on traditional debugging tools. The development cycle becomes:

```
Code → Deploy → Test → Read Logs → Understand Issue → Fix → Repeat
```

The speed of this cycle depends entirely on **log quality**. Bad logs = slow iteration. Good logs = rapid development.

---

## The Development Lifecycle

### Stage 1: Local Development (Mac)

**Goal**: Write and test code on your Mac before deploying to Pi

**Environment**:
- Frontend: `npm run dev` (Vite hot reload)
- Backend: Can't fully test (no microphone hardware)
- LLM: Ollama running on Mac or Pi

**What You Can Test**:
- Frontend UI rendering
- Component logic
- API service calls (mocked)
- Agent orchestration logic

**What You Can't Test**:
- Audio recording
- Hardware interactions
- Full end-to-end flow

**Logging Strategy**:
```javascript
// Frontend: Console logging with emoji prefixes
console.log('[WebSocket] 📨 Message received:', data);
console.log('[Recording] 🎤 Starting...');
console.error('[LLM] ❌ Error:', error);
```

**Why Emoji Prefixes?**
- Instant visual scanning of logs
- Grep-friendly: `grep "🎤" logs.txt`
- Shows component at a glance

---

### Stage 2: Deploy to Raspberry Pi

**Goal**: Get code onto Pi as fast as possible

**Current Method** (manual):
```bash
# From Mac
scp src/SimpleApp.jsx gbade@192.168.1.47:/home/gbade/maxheadbox/src/
scp backend/server_new.rb gbade@192.168.1.47:/home/gbade/maxheadbox/backend/

# On Pi
cd /home/gbade/maxheadbox
npm run build
```

**Better Method** (automated - to be created):
```bash
# From Mac
./scripts/deploy.sh

# This should:
# 1. Build frontend (npm run build)
# 2. rsync entire project to Pi (excluding node_modules)
# 3. Restart services on Pi
# 4. Tail logs to show deployment succeeded
```

**Time Saved**: Manual (2-3 min) → Automated (30 sec)

---

### Stage 3: Run & Monitor on Pi

**Goal**: See what's happening in real-time

**Current State**: Multiple services, multiple log locations
```
Backend:     /tmp/backend_live.log
Whisper:     /tmp/whisper.log
Frontend:    Browser console (can't access remotely)
Vite:        /tmp/vite.log
Wake-word:   /tmp/awaker.log
```

**Problems**:
1. ❌ Logs scattered across multiple files
2. ❌ No unified view of system state
3. ❌ Hard to correlate events across services
4. ❌ Browser console not accessible from Mac

**Solution**: Structured logging with unified output

---

## Logging Architecture (The Key to Rapid Iteration)

### Principle 1: Every Event Must Be Logged

**Bad** (Silent failure):
```ruby
def start_recording
  Process.spawn(command)
end
```

**Good** (Comprehensive logging):
```ruby
def start_recording
  @logger.info "[Recording] 🎤 Starting new recording..."
  pid = Process.spawn(command)
  @logger.info "[Recording] ✅ Started (PID: #{pid})"

  Thread.new do
    start_time = Time.now
    Process.wait(pid)
    duration = (Time.now - start_time).round(2)
    @logger.info "[Recording] ⏹️  Finished after #{duration}s"
  end
end
```

**What This Gives You**:
- Know when recording started
- Know the PID (can kill manually if needed)
- Know when it finished
- Know how long it took
- Can grep for "Recording" to see entire flow

---

### Principle 2: Log Context, Not Just Events

**Bad**:
```ruby
@logger.info "Transcription completed"
```

**Good**:
```ruby
@logger.info "[Transcription] ✅ Completed in #{duration}s → \"#{text}\""
```

**What Context Means**:
- **Timing**: How long did it take?
- **Data**: What was the result?
- **Component**: Which part of system?
- **Status**: Success or failure?

**Example Log Output**:
```
[Recording] 🎤 Starting new recording...
[Recording] ✅ Started (PID: 12345) file: /dev/shm/recording.wav
[Recording] ⏹️  Finished after 10.09s, file size: 293.5KB
[Transcription] 📝 Calling Whisper service...
[Transcription] ✅ Completed in 2.04s → "Hello there."
[WebSocket] 📤 Sent recording_finished event to 1 client(s)
[LLM] 💬 Calling Ollama (model: gemma3:1b, stream: false)
[LLM] ✅ Response received in 3.21s (156 chars)
```

**You Can Now Answer**:
- ✅ Did recording start? (Yes, PID 12345)
- ✅ How long did it record? (10.09s)
- ✅ Was audio captured? (Yes, 293KB file)
- ✅ Did transcription work? (Yes, got "Hello there.")
- ✅ How fast is Whisper? (2.04s)
- ✅ Did frontend get the data? (Yes, sent to 1 client)
- ✅ How fast is LLM? (3.21s)

**Without these logs**: You'd be guessing where it failed.

---

### Principle 3: Structured Log Format

**Format**: `[Component] {Emoji} {Action} {Details}`

**Components**:
- `[Recording]` - Audio recording
- `[Transcription]` - Speech-to-text
- `[LLM]` - Language model calls
- `[WebSocket]` - Real-time events
- `[Tool]` - Tool execution
- `[Agent]` - Agent orchestration

**Emojis** (Visual Status):
- 🎤 Starting recording
- ⏹️  Recording finished
- 📝 Processing/transcribing
- ✅ Success
- ❌ Error
- 💬 LLM call
- 📤 WebSocket send
- 📨 WebSocket receive
- ⚠️  Warning

**Why This Format?**
- Easy to grep: `grep "\[Recording\]" logs.txt`
- Visual scanning: See status at a glance
- Consistent across all services
- Machine parseable (for future log aggregation)

---

### Principle 4: Correlation IDs (Future Enhancement)

**Problem**: Multiple requests happening concurrently
```
[Recording] 🎤 Starting...
[Recording] 🎤 Starting...  # Which one is which?
[Transcription] ✅ Completed → "hello"  # From which recording?
```

**Solution**: Request IDs
```
[Recording:a3f2] 🎤 Starting...
[Recording:b8c1] 🎤 Starting...
[Transcription:a3f2] ✅ Completed → "hello"
[Transcription:b8c1] ✅ Completed → "goodbye"
```

**Implementation** (to be added):
```ruby
def start_recording
  request_id = SecureRandom.hex(4)
  @logger.info "[Recording:#{request_id}] 🎤 Starting..."
  # Pass request_id through the entire flow
end
```

---

## Unified Logging System (To Be Implemented)

### Current State (Fragmented)

```
# Backend logs
ssh gbade@192.168.1.47 'tail -f /tmp/backend_live.log'

# Whisper logs
ssh gbade@192.168.1.47 'tail -f /tmp/whisper.log'

# Frontend logs
# ❌ Can't access browser console remotely
```

### Proposed: Centralized Logging

**Option 1: Simple File Aggregation**
```bash
# On Pi: Aggregate all logs to one file with service prefix
./scripts/start_services.sh

# This redirects:
Backend  → /tmp/maxheadbox.log (prefix: [BACKEND])
Whisper  → /tmp/maxheadbox.log (prefix: [WHISPER])
Vite     → /tmp/maxheadbox.log (prefix: [VITE])

# Then from Mac:
ssh gbade@192.168.1.47 'tail -f /tmp/maxheadbox.log'
```

**Option 2: Remote Logging Server** (more advanced)
```javascript
// Frontend sends logs to backend
fetch('/logs', {
  method: 'POST',
  body: JSON.stringify({
    level: 'info',
    component: 'LLM',
    message: 'Response received',
    data: { duration: 3.2 }
  })
});

// Backend writes to unified log
# /tmp/maxheadbox.log:
# [FRONTEND:LLM] ✅ Response received (duration: 3.2s)
```

**Benefit**: See frontend AND backend logs in one place

---

## Debugging Workflow Examples

### Example 1: "Recording never stops"

**Without Good Logs**:
```
# You see: UI stuck on "Listening..."
# You don't know: Is sox running? Is it detecting silence? Did it crash?
# You try: Random guesses, restart services, check hardware
# Time wasted: 30 minutes
```

**With Good Logs**:
```bash
# From Mac:
ssh gbade@192.168.1.47 'tail -50 /tmp/maxheadbox.log'

# You see:
[Recording] 🎤 Starting new recording... (PID: 12345)
# ... no "Finished" message

# Check if process is still running:
ssh gbade@192.168.1.47 'ps aux | grep 12345'
# Yes, sox is still running after 5 minutes

# Check file size:
ssh gbade@192.168.1.47 'ls -lh /dev/shm/recording.wav'
# 111MB (way too big)

# Root cause identified: Silence detection not working
# Fix: Adjust sox parameters
# Time to fix: 5 minutes
```

---

### Example 2: "LLM not responding"

**Without Good Logs**:
```
# You see: UI shows "Thinking..." then back to "Ready"
# You don't know: Is LLM being called? Is it failing? Is response empty?
# You try: Restart Ollama, check network, rebuild frontend
# Time wasted: 20 minutes
```

**With Good Logs**:
```bash
ssh gbade@192.168.1.47 'grep "LLM" /tmp/maxheadbox.log'

# You see:
[Transcription] ✅ Completed → "Hello there."
# ... no LLM log

# Root cause: Frontend not calling LLM
# Check browser console remotely (new logging):
[FRONTEND:LLM] ❌ Error: Network request failed (CORS)

# Fix: Add CORS headers to Ollama
# Time to fix: 2 minutes
```

---

### Example 3: "Transcription is empty"

**Without Good Logs**:
```
# You see: No text appears after recording
# You don't know: Did recording work? Did Whisper run? Was file empty?
# Time wasted: 15 minutes testing microphone
```

**With Good Logs**:
```bash
ssh gbade@192.168.1.47 'grep -E "Recording|Transcription" /tmp/maxheadbox.log'

# You see:
[Recording] ⏹️  Finished after 10.09s, file size: 293.5KB
[Transcription] 📝 Calling Whisper service...
[Transcription] ✅ Completed in 0.13s → (empty - silence detected)

# Root cause: Microphone not capturing audio (file exists but silent)
# Test: Run test_record endpoint
# Fix: Check alsamixer volume levels
# Time to fix: 3 minutes
```

---

## Logging Best Practices (Code Standards)

### 1. Every Module Requires a Logger

```ruby
module Audio
  class Recorder
    def initialize(recordings_dir, logger)
      @recordings_dir = recordings_dir
      @logger = logger  # ✅ Always inject logger
    end
  end
end
```

### 2. Log State Transitions

```ruby
def start_recording
  @logger.info "[Recording] 🎤 Starting..."  # State: idle → recording
  # ... do work ...
  @logger.info "[Recording] ✅ Started"       # State: recording (confirmed)
end

def stop_recording
  @logger.info "[Recording] Stopping..."     # State: recording → stopping
  # ... do work ...
  @logger.info "[Recording] ⏹️  Stopped"     # State: idle
end
```

### 3. Log Errors with Full Context

**Bad**:
```ruby
rescue => e
  @logger.error e.message
end
```

**Good**:
```ruby
rescue => e
  @logger.error "[Recording] ❌ Error starting recording: #{e.message}"
  @logger.error "  File: #{filepath}"
  @logger.error "  Command: #{command}"
  @logger.error "  Backtrace: #{e.backtrace.first(5).join("\n  ")}"
end
```

### 4. Log Performance Metrics

```ruby
def transcribe(file_path)
  start_time = Time.now
  @logger.info "[Transcription] 📝 Calling Whisper service..."

  result = call_whisper_api(file_path)

  duration = (Time.now - start_time).round(2)
  @logger.info "[Transcription] ✅ Completed in #{duration}s → \"#{result[:text]}\""

  result
end
```

**Why?** You can track performance over time:
```bash
# Is Whisper getting slower?
grep "Transcription.*Completed" /tmp/maxheadbox.log | tail -20

# Average transcription time:
grep "Transcription.*Completed" /tmp/maxheadbox.log | \
  grep -oP 'in \K[0-9.]+' | \
  awk '{s+=$1; n++} END {print s/n "s average"}'
```

---

## Development Tools to Build

### 1. Unified Log Viewer Script

**File**: `scripts/view_logs.sh`
```bash
#!/bin/bash
# View all Max Headbox logs in real-time with color coding

ssh gbade@192.168.1.47 '
  tail -f /tmp/maxheadbox.log | \
  sed -e "s/\[BACKEND\]/$(tput setaf 1)[BACKEND]$(tput sgr0)/" \
      -e "s/\[WHISPER\]/$(tput setaf 2)[WHISPER]$(tput sgr0)/" \
      -e "s/\[FRONTEND\]/$(tput setaf 4)[FRONTEND]$(tput sgr0)/" \
      -e "s/✅/$(tput setaf 2)✅$(tput sgr0)/" \
      -e "s/❌/$(tput setaf 1)❌$(tput sgr0)/"
'
```

**Usage**:
```bash
./scripts/view_logs.sh
# See all logs, color-coded, in real-time
```

---

### 2. Deployment Script with Log Verification

**File**: `scripts/deploy.sh`
```bash
#!/bin/bash
set -e

echo "📦 Building frontend..."
npm run build

echo "🚀 Deploying to Pi..."
rsync -avz --exclude 'node_modules' ./ gbade@192.168.1.47:/home/gbade/maxheadbox/

echo "🔄 Restarting services..."
ssh gbade@192.168.1.47 'cd /home/gbade/maxheadbox && ./scripts/restart_services.sh'

echo "📊 Watching logs for 10 seconds to verify deployment..."
timeout 10 ssh gbade@192.168.1.47 'tail -f /tmp/maxheadbox.log' || true

echo "✅ Deployment complete!"
```

---

### 3. Service Health Check Script

**File**: `scripts/health_check.sh`
```bash
#!/bin/bash
# Check all services are running and healthy

echo "🏥 Max Headbox Health Check"
echo "=============================="

# Check backend
if curl -s http://192.168.1.47:4567/ | grep -q "Sinatra is ok"; then
  echo "✅ Backend: Running"
else
  echo "❌ Backend: Down"
fi

# Check Whisper
if curl -s http://192.168.1.47:8000/ | grep -q "Whisper up and running"; then
  echo "✅ Whisper: Running"
else
  echo "❌ Whisper: Down"
fi

# Check Ollama
if curl -s http://192.168.1.47:11434/api/tags > /dev/null 2>&1; then
  echo "✅ Ollama: Running"
else
  echo "❌ Ollama: Down"
fi

# Check frontend
if curl -s http://192.168.1.47:4173/ > /dev/null 2>&1; then
  echo "✅ Frontend: Running"
else
  echo "❌ Frontend: Down"
fi

echo ""
echo "📊 Recent logs (last 10 lines):"
ssh gbade@192.168.1.47 'tail -10 /tmp/maxheadbox.log'
```

---

## Log Retention & Rotation

**Current Problem**: Logs grow forever, fill disk

**Solution**: Rotate logs daily

**File**: `/etc/logrotate.d/maxheadbox` (on Pi)
```
/tmp/maxheadbox.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 0644 gbade gbade
}
```

**What this does**:
- Keep 7 days of logs
- Compress old logs (maxheadbox.log.1.gz)
- Create new log file each day
- Delete logs older than 7 days

---

## Metrics to Track (Future)

Once logging is solid, you can extract metrics:

**Performance Metrics**:
- Average recording duration
- Average transcription time
- Average LLM response time
- End-to-end latency (speech → response)

**Usage Metrics**:
- Recordings per day
- Wake-word detection accuracy
- Most common questions
- Error rates per component

**Implementation**:
```bash
# Extract metrics from logs
./scripts/generate_metrics.sh

# Example output:
# Recordings today: 47
# Avg transcription time: 1.8s
# Avg LLM response time: 3.2s
# Error rate: 2.1% (1/47)
```

---

## Summary: Why This Matters

### The Iteration Cycle

**Without Good Logging**:
```
Code → Deploy → Test → ??? → Guess → Random Fix → Repeat
Cycle time: 30-60 minutes per issue
```

**With Good Logging**:
```
Code → Deploy → Test → Read Logs → Understand → Fix → Repeat
Cycle time: 5-10 minutes per issue
```

### The Difference

**Bad Logging**:
- "Why isn't this working?" → 30 min of guessing
- "Did that fix it?" → Deploy and pray
- "Is it the frontend or backend?" → Who knows

**Good Logging**:
- "Why isn't this working?" → Check logs, see exact failure point
- "Did that fix it?" → Logs show success/failure immediately
- "Is it the frontend or backend?" → Logs show component name

### Development Velocity

**With proper logging**:
- ✅ Deploy fixes in minutes, not hours
- ✅ Catch regressions immediately
- ✅ Understand performance bottlenecks
- ✅ Debug production issues remotely
- ✅ Build confidence in your code

**Without it**:
- ❌ Spend hours debugging simple issues
- ❌ Fear deployments (might break things)
- ❌ Can't debug production remotely
- ❌ Slow, frustrating development

---

## Action Items for Next Session

1. **Implement unified logging** - All services log to `/tmp/maxheadbox.log`
2. **Create deployment script** - One command to deploy and verify
3. **Create log viewer script** - Color-coded real-time log viewing
4. **Add frontend logging** - Send browser logs to backend
5. **Set up log rotation** - Prevent disk filling

**Once these are in place**: Development velocity will increase 5-10x.

This is the foundation that makes rapid iteration possible.
