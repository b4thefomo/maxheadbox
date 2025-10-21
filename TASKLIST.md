# Max Headbox Development Tasklist

## Phase 1: Architecture Refactoring ✅ COMPLETE

### Backend Modularization
- [x] Create `backend/audio/recorder.rb` module
- [x] Create `backend/audio/transcriber.rb` module
- [x] Create `backend/llm/gateway.rb` module
- [x] Create `backend/core/websocket_manager.rb` module
- [x] Create `backend/server_new.rb` using modular architecture
- [x] Implement logger injection across all modules
- [x] Add structured logging with emoji prefixes

### Documentation
- [x] Create `DEVELOPMENT_LIFECYCLE.md` - Development workflow and logging philosophy
- [x] Create `MODULAR_ARCHITECTURE.md` - Module breakdown and benefits
- [x] Create `ARCHITECTURE_DIAGRAMS.md` - 11 Mermaid diagrams
- [x] Update `CLAUDE.md` with architecture references
- [x] Create this `TASKLIST.md` checklist

### Development Scripts
- [x] Create `scripts/deploy.sh` - One-command deployment
- [x] Create `scripts/health_check.sh` - Service health verification
- [x] Create `scripts/view_logs.sh` - Real-time log viewer
- [x] Create `scripts/README.md` - Scripts documentation
- [x] Make all scripts executable

---

## Phase 2: Testing & Deployment 🔄 IN PROGRESS

### Backend Migration
- [ ] Deploy `server_new.rb` to Raspberry Pi
- [ ] Test all routes with modular backend
  - [ ] `/` - Health check endpoint
  - [ ] `/start_recording` - Recording initiation
  - [ ] `/wake` - Wake word detection
  - [ ] WebSocket connections and broadcasts
- [ ] Verify logging output in `/tmp/backend.log`
- [ ] Run health checks to confirm services
- [ ] Test full voice → transcription → response flow

### Frontend Compatibility
- [ ] Verify `SimpleApp.jsx` works with `server_new.rb`
- [ ] Test WebSocket event handling
- [ ] Confirm recording state management
- [ ] Verify Ollama LLM calls from frontend

### Performance Validation
- [ ] Measure recording latency
- [ ] Measure transcription time
- [ ] Measure LLM response time
- [ ] Compare against previous monolithic implementation
- [ ] Document any performance differences

---

## Phase 3: Frontend Modularization 📋 PLANNED

### React Component Refactoring
- [ ] Extract recording logic into `useRecording` hook
- [ ] Extract WebSocket logic into `useWebSocket` hook
- [ ] Extract LLM interaction into `useLLM` hook
- [ ] Create `services/` directory for API clients
- [ ] Separate UI components from business logic

### State Management
- [ ] Consider React Context for global state
- [ ] Refactor `globalMessagesRef` usage
- [ ] Clean up status management (`APP_STATUS`)

---

## Phase 4: System Hardening 🛡️ PLANNED

### Error Handling
- [ ] Add comprehensive error boundaries in React
- [ ] Implement retry logic for failed recordings
- [ ] Add timeout handling for LLM calls
- [ ] Improve WebSocket reconnection logic
- [ ] Add graceful degradation when services are down

### Logging Enhancements
- [ ] Implement unified logging to single file (`/tmp/maxheadbox.log`)
- [ ] Add log rotation (prevent disk fill)
- [ ] Create frontend → backend logging (browser console → backend logs)
- [ ] Add structured JSON logging option
- [ ] Create log analysis script (`scripts/analyze_logs.sh`)

### Monitoring
- [ ] Add performance metrics collection
- [ ] Create dashboard for system health
- [ ] Add alerting for service failures
- [ ] Monitor disk space in `/dev/shm/`
- [ ] Track recording success/failure rates

---

## Phase 5: Feature Enhancements 🚀 FUTURE

### Wake Word System
- [ ] Test wake word reliability
- [ ] Add multiple wake word support
- [ ] Implement wake word confidence threshold
- [ ] Add visual feedback for wake word detection

### Tool System Improvements
- [ ] Complete migration of `.txt` tools to `.js`
- [ ] Add tool execution logging
- [ ] Create tool testing framework
- [ ] Document tool creation process
- [ ] Add dangerous tool safeguards

### User Experience
- [ ] Add visual feedback during recording
- [ ] Improve error messages for users
- [ ] Add configuration UI
- [ ] Implement voice feedback (text-to-speech)
- [ ] Add conversation history persistence

### Developer Experience
- [ ] Add `scripts/start_services.sh` - Start without deploying
- [ ] Add `scripts/stop_services.sh` - Stop all services
- [ ] Add `scripts/generate_metrics.sh` - Extract performance metrics
- [ ] Create automated testing suite
- [ ] Add CI/CD pipeline

---

## Phase 6: Production Readiness 🎯 FUTURE

### Security
- [ ] Add authentication for backend routes
- [ ] Implement rate limiting
- [ ] Sanitize file paths in recording logic
- [ ] Review and fix security vulnerabilities
- [ ] Add HTTPS support

### Performance
- [ ] Optimize Ollama model loading
- [ ] Reduce frontend bundle size
- [ ] Implement lazy loading for tools
- [ ] Cache transcription results
- [ ] Optimize recording buffer size

### Documentation
- [ ] Create user manual
- [ ] Add troubleshooting guide
- [ ] Document deployment to different hardware
- [ ] Create video tutorials
- [ ] Add API documentation

---

## Notes

### Current Status
We've completed Phase 1 (Architecture Refactoring) and created all documentation and scripts. The new modular backend (`server_new.rb`) is ready to test but hasn't been deployed yet.

### Next Immediate Steps
1. Deploy using `./scripts/deploy.sh`
2. Run `./scripts/health_check.sh` to verify services
3. Test the complete voice interaction flow
4. Monitor logs with `./scripts/view_logs.sh`
5. Fix any issues that arise

### Development Philosophy
Remember: **Logging enables rapid iteration**. Every new feature or bug fix should:
1. Be thoroughly logged
2. Use structured format `[Component] {Emoji} {Action} {Details}`
3. Include performance metrics (duration, counts)
4. Provide enough context to debug without SSH access

### Time Estimates
- Phase 2 (Testing): 2-3 hours
- Phase 3 (Frontend): 1-2 days
- Phase 4 (Hardening): 2-3 days
- Phase 5 (Features): 1-2 weeks
- Phase 6 (Production): 1-2 weeks

**Total to production-ready**: ~4-6 weeks of focused work
