# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

To ssh into my raspberryPi you can use gbade@192.168.1.47

## Project Overview

Max Headbox is a voice-activated LLM Agent designed to run on a Raspberry Pi. It combines a React frontend with a Ruby/Python backend to create an interactive virtual companion that can execute tools and respond to voice commands.

The project uses a custom agentic workflow (not tool calling APIs) where the LLM generates JSON payloads to invoke tools, allowing the frontend to contain the main Agent logic while the backend handles hardware interactions.

## Architecture

**📚 See comprehensive documentation:**
- **[ARCHITECTURE_DIAGRAMS.md](./ARCHITECTURE_DIAGRAMS.md)** - 11 Mermaid diagrams showing complete system (Hardware → Kernel → Services → Application)
- **[MODULAR_ARCHITECTURE.md](./MODULAR_ARCHITECTURE.md)** - Modular backend design with clean separation of concerns
- **[DEVELOPMENT_LIFECYCLE.md](./DEVELOPMENT_LIFECYCLE.md)** - Development workflow and logging best practices
- **[SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md)** - Original system architecture documentation

### Modular Architecture (NEW)

The backend has been refactored into clean, testable modules:

**Backend Structure:**
```
backend/
├── server_new.rb          # Main server (260 lines, just routes)
├── audio/                 # Audio processing module
│   ├── recorder.rb        # Recording logic (sox wrapper)
│   ├── transcriber.rb     # Whisper API client
│   └── whisper_service.py # FastAPI transcription service
├── llm/                   # LLM interactions module
│   └── gateway.rb         # Ollama API wrapper
├── tools/                 # External integrations
│   ├── weather.rb, wiki.rb, sysinfo.rb, notes.rb
└── core/                  # Shared utilities
    └── websocket_manager.rb
```

**Key Benefits:**
- Single responsibility per module
- Logger injected into every module for comprehensive debugging
- Easy to test components independently
- Clean API boundaries

### Three-Tier System

1. **Frontend (React + Vite)**: Contains the core Agent logic, connects directly to Ollama, handles UI/UX
2. **Backend (Modular Ruby)**: Clean modules for audio, LLM, tools, and core utilities
3. **Python Services**: Runs voice transcription (faster-whisper) and wake-word detection (Vosk)

### Key Flow

1. Wake-word detection (`awaker.py`) listens for "max" using Vosk
2. When detected, sends POST to `/wake` endpoint
3. Backend starts recording via `rec` command
4. Recording stops on silence, file sent to `whisper_service.py` for transcription
5. Transcribed text sent to frontend via WebSocket
6. Frontend's Agent (`App.jsx`) determines which tools to call using `qwen3:1.7b`
7. Conversation model (`gemma3:1b`) generates responses with emotion/feeling
8. Response rendered in UI with animated face reactions

### Two LLM System

**Agent Model** (`systemPrompt.js` - agent):
- Model: `qwen3:1.7b`
- Breaks down user requests into sequential function calls
- Outputs JSON: `{"function":"name","describe":"intent","parameter":"value"}`
- Loops up to 5 times until calls `finished()` function

**Conversation Model** (`systemPrompt.js` - conversation):
- Model: `gemma3:1b`
- Handles natural language responses and personality
- Outputs JSON: `{"message":"text","feeling":"emotion"}`
- Feelings map to animated face reactions

### Tool System

Tools are JavaScript modules in `src/tools/` with structure:
```javascript
export default {
  name: 'tool_name',
  params: 'parameter_description', // or undefined
  description: 'what this tool does',
  execution: async (parameter) => { /* implementation */ },
  dangerous: false // optional
}
```

Some tools require backend API handlers in `backend/notions/*.rb` to access Raspberry Pi hardware.

### State Management

- `globalAgentChatRef`: Tracks agent's tool-calling conversation history
- `globalMessagesRef`: Tracks user/assistant conversation history
- `APP_STATUS`: Manages UI states (IDLE, RECORDING, THINKING, SPEAKING, etc.)
- WebSocket handles async events (wake word, recording finished, errors)

## Development Scripts (NEW)

**Quick deployment and monitoring:**

```bash
# Deploy to Raspberry Pi (builds, syncs, restarts, verifies)
./scripts/deploy.sh

# Check all services are running and healthy
./scripts/health_check.sh

# View real-time logs from all services (color-coded)
./scripts/view_logs.sh
```

See [scripts/README.md](./scripts/README.md) for complete documentation.

## Development Commands

### Frontend
```bash
# Install dependencies (uses Node 22)
nvm use
npm install

# Development mode (hot reload)
npm run dev

# Build production
npm run build

# Preview production build
npm run preview

# Lint
npm run lint
```

### Backend
```bash
# Install Ruby dependencies (requires Ruby 3.3.0)
cd backend/
bundle install

# Install Python dependencies (requires Python 3)
pip3 install -r requirements.txt

# Start backend server (Sinatra on port 4567)
npm run start-backend  # from root
# or
ruby backend/server.rb -o 0.0.0.0

# Start Whisper service (FastAPI on port 8000)
npm run start-whisper-service  # from root
# or
uvicorn backend.whisper_service:app --host 0.0.0.0 --port 8000 --workers 2
```

### Full Stack
```bash
# Development: starts Vite dev server + backend + whisper service
npm run dev-start

# Production: builds and starts all services
npm run prod-start
```

## Ollama Setup

Required models:
```bash
ollama pull gemma3:1b      # Conversation model
ollama pull qwen3:1.7b     # Agent/tool-calling model
```

Expose Ollama to network:
```bash
sudo systemctl edit ollama.service
# Add: Environment="OLLAMA_HOST=0.0.0.0"
sudo systemctl daemon-reload && sudo systemctl restart ollama
```

## Environment Configuration

`.env` file variables:
- `VITE_BACKEND_URL`: Sinatra server URL (default: `http://192.168.0.1:4567`)
- `VITE_WEBSOCKET_URL`: WebSocket URL (default: `ws://192.168.0.1:4567`)
- `VITE_OLLAMA_URL`: Ollama API URL (default: `http://192.168.0.1:11434`)
- `RECORDINGS_DIR`: Where audio recordings are stored (default: `/dev/shm/whisper_recordings`)

Change `RECORDINGS_DIR` for non-Linux development (e.g., `~/Desktop/whisper_recordings`).

## Creating New Tools

### Frontend Tool (no hardware access needed)
Create `src/tools/your_tool.js`:
```javascript
export default {
  name: 'your_tool',
  params: 'parameter_name',
  description: 'what it does',
  execution: async (parameter) => {
    // implementation
    return 'result string';
  }
}
```

Tool is automatically discovered via `import.meta.glob()` in `toolProcessor.js`.

### Backend Tool (requires hardware/external APIs)
1. Create frontend tool that calls backend route
2. Create `backend/notions/your_notion.rb`:
```ruby
get '/your-route/:param' do
  content_type :json
  # implementation
  { result: 'data' }.to_json
end
```

Backend automatically loads all `backend/notions/**/*.rb` files (see `server.rb:238`).

### Tools with `.txt` Extension
These are reference implementations. Rename to `.js` (frontend) or `.rb` (backend) to activate them.

## WebSocket Events

Backend sends these events to frontend:
- `wake_word_received`: Wake word detected, start recording
- `process_recording`: Recording finished, transcribing
- `recording_finished`: Transcription complete, includes `output` field
- `recording_error`: Error during recording/transcription

## Important Implementation Details

- Direct Ollama connection from frontend enables streaming responses
- Agent uses `role: 'user'` instead of `role: 'system'` for tool results (line App.jsx:218) - noted as faster
- Tool loop has guard of 5 iterations to prevent infinite loops
- Tools returning `undefined` skip agent flow and go straight to conversation
- Consecutive identical function calls trigger console warning (potential loop detection)
- `keep_alive: -1` keeps Ollama models loaded in memory
- Ruby backend uses `thin` server for WebSocket support

## Code Architecture Notes

- `src/config.js`: Environment variable imports and configuration
- `src/utils.js`: Stream processing helpers
- `src/Faces.jsx`: Animated emoji faces (modified Microsoft Fluent Emoji)
- `src/WordsContainer.jsx`: Message display component
- `backend/server.rb`: Main Sinatra app with recording/WebSocket logic
- Process management: Ruby backend spawns and kills child processes for recording and wake-word detection

## Testing Notes

When testing tools:
- Check both frontend execution and backend route if applicable
- Test tool parameter handling (empty string vs. actual values)
- Verify tool appears in `systemPrompt.js` generated examples
- Ensure tool returns string result for Agent to process
