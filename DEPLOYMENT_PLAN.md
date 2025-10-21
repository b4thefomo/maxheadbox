# Max Headbox Deployment Plan

## Recent Changes (2025-10-20)

### ✅ Phase 1: Quick Wins - COMPLETED

**1. Replaced Face Animations with Typography**
- **Problem:** Complex Faces.jsx component (~177 lines) with animation state bugs causing black screen crashes
- **Solution:** Created simple StatusDisplay.jsx component with emoji-based status indicators
- **Status Displays:**
  - 🎤 Listening... (recording)
  - 🤔 Thinking... (processing)
  - 📖 Processing... (reading/transcribing)
  - ❤️ Got it! (successful transcription)
  - ❌ Error (failed operation)
  - 😊 Hey there! (idle)
  - 😴 Resting... (sleepy/screensaver)
  - 💬 Speaking... (LLM responding)
- **Files Modified:**
  - Created: `src/StatusDisplay.jsx`, `src/StatusDisplay.css`
  - Modified: `src/App.jsx` (replaced Faces import with StatusDisplay)
- **Result:** No more UI crashes, cleaner codebase, easier to debug

**2. Fixed Empty Transcription Issue**
- **Problem:** Whisper returning empty arrays despite good audio levels
- **Root Cause:**
  - "tiny.en" model too aggressive/small
  - Test recordings had no actual speech (background noise only)
  - Volume levels improved but still needed better model
- **Solution:**
  - Upgraded: `tiny.en` → `base.en` Whisper model (better accuracy)
  - Added: Volume boost (`gain 20` in sox recording commands)
  - Improved: VAD filtering with tuned parameters
  - Added: Filter to skip hallucinated single-character segments
  - Enhanced: Beam search settings (beam_size=5, best_of=5)
- **Files Modified:**
  - `backend/server.rb` (line 97, 199): Added `gain 20` to sox commands
  - `backend/whisper_service.py`: Upgraded model, added filtering
- **Result:** Transcription now works reliably with actual speech

**3. Deployment & Testing**
- All services running on Raspberry Pi:
  - ✅ Frontend: http://192.168.1.47:4173/
  - ✅ Backend: Port 4567 (Sinatra with WebSocket)
  - ✅ Whisper: Port 8000 (FastAPI with base.en model)
- Test recording button functional
- Typography status display working correctly

---

## Architecture Simplification Notes

**Current Stack Issues:**
- Requires 3 language runtimes: Node.js 22 + Ruby 3.3.0 + Python 3
- Ruby backend (Sinatra) could be replaced with Python (FastAPI/Flask) since Python is already required for Whisper
- This would eliminate Ruby dependency entirely
- Backend only needs: WebSocket server, audio recording management, simple REST routes

**Proposed Simplification:**
1. **Keep:** Node.js (frontend/Vite) + Python (everything backend)
2. **Migrate:** All Ruby Sinatra code → Python FastAPI (already using it for whisper_service)
3. **Consolidate:** Merge `whisper_service.py` and `server.rb` into single FastAPI app
4. **Benefits:**
   - 2 runtimes instead of 3
   - Easier deployment and dependency management
   - Python better suited for AI/ML tooling ecosystem
   - FastAPI has built-in WebSocket support

**Alternative (even simpler):**
- Use Bun instead of Node.js - can run both frontend AND backend in single runtime
- Bun has native TypeScript support, fast package manager, and can replace both Node + Python for many tasks
- Would still need Python for faster-whisper/Vosk unless using JS alternatives

---

## Current State Analysis

**✅ Already Installed on Pi:**
- Node.js v20.19.2 (needs upgrade to v22)
- Python 3.13.5 ✅
- Ollama 0.12.5 ✅ (running as service)
- Ollama has `gemma3:270m` model (need `gemma3:1b` and `qwen3:1.7b`)
- IP: 192.168.1.47 ✅

**❌ Missing:**
- Ruby 3.3.0 and bundler
- maxheadbox codebase
- Sox/ALSA audio tools (`rec`, `aplay`)
- Required Ollama models (gemma3:1b, qwen3:1.7b)
- Vosk wake-word model files
- Python dependencies (faster-whisper, vosk, fastapi, etc.)

**⚠️ Configuration Issues:**
- `.env` file has wrong IP (192.168.0.1 should be 192.168.1.47)
- Ollama not exposed to network (missing `OLLAMA_HOST=0.0.0.0`)

---

## Deployment Steps

### 1. Install Ruby & Dependencies on Pi
```bash
ssh gbade@192.168.1.47
sudo apt update
sudo apt install -y rbenv ruby-build
rbenv install 3.3.0
rbenv global 3.3.0
gem install bundler
```

### 2. Upgrade Node.js to v22
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install 22
nvm use 22
nvm alias default 22
```

### 3. Install Audio Tools
```bash
sudo apt install -y sox alsa-utils
# Test microphone
arecord -l
```

### 4. Clone & Configure Repository
```bash
cd ~
git clone https://github.com/syxanash/maxheadbox.git
cd maxheadbox

# Update .env file
sed -i 's/192.168.0.1/192.168.1.47/g' .env

# Create recordings directory
sudo mkdir -p /dev/shm/whisper_recordings
sudo chown gbade:gbade /dev/shm/whisper_recordings
```

### 5. Download Vosk Wake-Word Model
```bash
cd ~/maxheadbox/backend
mkdir -p assets
cd assets
wget https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip
unzip vosk-model-small-en-us-0.15.zip
rm vosk-model-small-en-us-0.15.zip
```

### 6. Install Project Dependencies
```bash
cd ~/maxheadbox

# Backend Ruby dependencies
cd backend
bundle install
cd ..

# Python dependencies
pip3 install -r backend/requirements.txt

# Frontend dependencies
npm install
```

### 7. Configure Ollama
```bash
# Expose Ollama to network
sudo systemctl edit ollama.service
# Add these lines:
# [Service]
# Environment="OLLAMA_HOST=0.0.0.0"

sudo systemctl daemon-reload
sudo systemctl restart ollama

# Pull required models (will take time)
ollama pull gemma3:1b
ollama pull qwen3:1.7b
```

### 8. Build & Start Application
```bash
cd ~/maxheadbox

# Build frontend
npm run build

# Start all services (Vite preview + Sinatra + Whisper)
npm run prod-start
```

### 9. Access & Test
- Open browser: `http://192.168.1.47:4173` (Vite preview port)
- Click screen to boot Max
- Say "max" to trigger wake word
- Speak your command
- Verify response

---

## Troubleshooting

**If wake word doesn't work:**
- Check microphone with: `arecord -d 5 test.wav && aplay test.wav`
- Check awaker.py logs for errors
- Verify Vosk model path exists

**If Ollama fails:**
- Check models loaded: `ollama list`
- Check service: `systemctl status ollama`
- Check memory: Models need ~6GB RAM

**If recording fails:**
- Verify sox installed: `which rec`
- Check /dev/shm permissions: `ls -la /dev/shm/whisper_recordings`

**If transcription fails:**
- Check whisper service: `curl http://localhost:8000/`
- Check Python dependencies: `pip3 list | grep faster-whisper`
