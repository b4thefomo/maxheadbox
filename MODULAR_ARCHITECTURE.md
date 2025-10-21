# Modular Architecture Documentation

## Overview

Max Headbox has been refactored into a **Modular Monolith** architecture - all code remains in one repository, but it's organized into clean, well-separated modules with single responsibilities.

## File Structure

```
maxheadbox/
├── backend/
│   ├── server_new.rb           # Main server (refactored, clean)
│   ├── server.rb               # Old server (keep for reference)
│   │
│   ├── audio/                  # AUDIO MODULE
│   │   ├── recorder.rb         # Recording logic (sox wrapper)
│   │   ├── transcriber.rb      # Whisper API client
│   │   └── whisper_service.py  # FastAPI transcription service
│   │
│   ├── llm/                    # LLM MODULE
│   │   └── gateway.rb          # Ollama API wrapper
│   │
│   ├── tools/                  # TOOLS MODULE
│   │   ├── weather.rb          # Weather API integration
│   │   ├── wiki.rb             # Wikipedia API integration
│   │   ├── sysinfo.rb          # System information (CPU, uptime)
│   │   ├── notes.rb            # File-based notes storage
│   │   ├── email.rb            # Email sending via SMTP
│   │   └── fortune.rb          # Unix fortune command
│   │
│   ├── core/                   # CORE UTILITIES
│   │   └── websocket_manager.rb # WebSocket broadcast helper
│   │
│   └── notions/                # OLD TOOLS (keep for reference)
│
├── src/                        # FRONTEND (to be modularized next)
│   ├── SimpleApp.jsx           # Current UI
│   ├── components/             # (to be created)
│   ├── services/               # (to be created - API clients)
│   └── agent/                  # (to be created - agent logic)
│
└── config/
    ├── .env                    # Environment variables
    └── .env.local              # Local overrides
```

## Module Responsibilities

### Audio Module (`backend/audio/`)

**Purpose**: Handle all voice/audio processing

**Components**:
- `recorder.rb` - Manages sox recording process with silence detection
- `transcriber.rb` - Calls Whisper service for speech-to-text
- `whisper_service.py` - FastAPI service running faster-whisper model

**API**:
```ruby
# Create recorder
recorder = Audio::Recorder.new(recordings_dir, logger)

# Start recording
recorder.start  # Returns { message, filename, filepath, pid }

# Check status
recorder.recording?  # Returns true/false

# Stop recording
recorder.stop  # Sends SIGINT to process

# Wait for completion (background thread)
recorder.wait_for_completion(callback)

# Test recording (5 seconds, no silence detection)
recorder.test_record
```

```ruby
# Create transcriber
transcriber = Audio::Transcriber.new(whisper_url, logger)

# Transcribe audio file
result = transcriber.transcribe(filepath)
# Returns { segments: [], text: "", duration: 0.0, error: nil }
```

---

### LLM Module (`backend/llm/`)

**Purpose**: Abstract Ollama API interactions

**Components**:
- `gateway.rb` - Ollama API wrapper with logging

**API**:
```ruby
# Create gateway
llm = LLM::Gateway.new(ollama_url, logger)

# Generate response
result = llm.generate(
  model: 'gemma3:1b',
  prompt: 'Your prompt here',
  stream: false,
  keep_alive: -1
)
# Returns { success: true, response: "...", model: "...", duration: 0.0 }

# List models
llm.models  # Returns Ollama models list

# Health check
llm.health_check  # Returns true/false
```

---

### Tools Module (`backend/tools/`)

**Purpose**: External integrations and system utilities

**Components** (all inherited from old `notions/` folder):
- `weather.rb` - Open-Meteo API integration
- `wiki.rb` - Wikipedia API integration
- `sysinfo.rb` - Raspberry Pi system info (CPU temp, uptime)
- `notes.rb` - File-based notes (save/read/clear)
- `email.rb` - SMTP email sending
- `fortune.rb` - Unix fortune command

**Note**: These still define routes in the old style. They can be refactored into classes later if needed.

---

### Core Module (`backend/core/`)

**Purpose**: Shared utilities

**Components**:
- `websocket_manager.rb` - Helper for WebSocket broadcasting

**API**:
```ruby
# Create manager
ws_manager = Core::WebSocketManager.new(sockets_array, logger)

# Broadcast to all clients
ws_manager.broadcast({ event: 'recording_finished', output: 'text' })

# Send to specific client
ws_manager.send_to(socket, { event: 'wake_word_received' })

# Manage clients
ws_manager.add_client(socket)
ws_manager.remove_client(socket)
ws_manager.client_count  # Returns integer
```

---

## New Server Routes (`server_new.rb`)

### Audio Routes
- `POST /start_recording` - Start recording with silence detection
- `POST /stop_recording` - Manually stop recording
- `GET /is_recording` - Check recording status
- `POST /test_record` - 5-second test recording

### LLM Routes (NEW)
- `POST /llm/generate` - Generate LLM response
- `GET /llm/models` - List available models
- `GET /llm/health` - Health check

### Wake-Word Routes
- `POST /spawn-listener` - Start wake-word detection
- `POST /wake` - Wake-word detected callback

### WebSocket
- `GET /ws` - WebSocket connection for real-time events

### Tool Routes
- Still loaded from `backend/tools/*.rb` files
- Same endpoints as before: `/weather/:city`, `/wiki/:query`, etc.

---

## Key Improvements

### Before (Monolithic)
- All logic in one 320-line `server.rb` file
- Recording, transcription, WebSocket logic mixed together
- Hard to test individual components
- Difficult to swap implementations (e.g., Vosk → Porcupine)

### After (Modular)
- Clear separation of concerns
- Each module has single responsibility
- Easy to test modules independently
- Can swap implementations without touching server code
- Much cleaner `server_new.rb` (260 lines, mostly routes)

---

## Migration Status

### ✅ Completed
- Backend module structure created
- Audio module extracted (recorder, transcriber)
- LLM module created (gateway)
- Tools copied to new location
- Core utilities created (WebSocket manager)
- New modular server created (`server_new.rb`)

### 🔄 In Progress
- Frontend modularization (to be done)

### 📋 To Do
- Create `src/services/` for API clients
- Create `src/agent/` for agent orchestration
- Simplify `SimpleApp.jsx` to UI-only component
- Test refactored system end-to-end
- Switch from `server.rb` to `server_new.rb` in production

---

## Testing the New Server

1. **Start Whisper service**:
   ```bash
   cd backend/audio
   uvicorn whisper_service:app --host 0.0.0.0 --port 8000
   ```

2. **Start new backend**:
   ```bash
   cd backend
   ruby server_new.rb -o 0.0.0.0
   ```

3. **Test recording**:
   ```bash
   curl -X POST http://localhost:4567/start_recording
   # Wait for recording to finish
   # Check WebSocket for transcription event
   ```

4. **Test LLM**:
   ```bash
   curl -X POST http://localhost:4567/llm/generate \
     -H "Content-Type: application/json" \
     -d '{"model":"gemma3:1b","prompt":"Hello!"}'
   ```

---

## Benefits

1. **Maintainability**: Each module is self-contained and easy to understand
2. **Testability**: Can mock modules independently
3. **Flexibility**: Easy to swap implementations (e.g., different transcription service)
4. **Scalability**: Clear path to extract modules into microservices if needed
5. **Developer Experience**: Much easier to onboard new developers

---

## Future Enhancements

- Add module-level unit tests
- Create Docker Compose for local development
- Add configuration management (YAML/JSON config files)
- Create deployment scripts
- Add API documentation (OpenAPI/Swagger)
- Consider extracting audio service to separate process for better isolation
