# Max Headbox Backend Server - Modular Architecture
# Clean separation of concerns with module-based design

require 'sinatra'
require 'json'
require 'sinatra-websocket'
require 'dotenv'
require 'logger'

# Load environment variables
Dotenv.load(File.join(File.dirname(__FILE__), '..', '.env.local'), File.join(File.dirname(__FILE__), '..', '.env'))

# Load modules
require_relative 'audio/recorder'
require_relative 'audio/transcriber'
require_relative 'llm/gateway'
require_relative 'core/websocket_manager'

# Load all tool routes
Dir['./backend/tools/**/*.rb'].each { |f| require f }

# Server configuration
set :server, 'thin'
set :sockets, []
set :threaded, true

# Configuration
RECORDINGS_DIR = File.expand_path(ENV['RECORDINGS_DIR'] || '/dev/shm/whisper_recordings', File.dirname(__FILE__))
FileUtils.mkdir_p(RECORDINGS_DIR) unless Dir.exist?(RECORDINGS_DIR)

WHISPER_URL = ENV['WHISPER_URL'] || 'http://localhost:8000'
OLLAMA_URL = ENV['VITE_OLLAMA_URL'] || 'http://localhost:11434'
BACKEND_URL = ENV['VITE_BACKEND_URL'] || 'http://localhost:4567'

# Global state
$recorder = nil
$listener_pid = nil

# Cleanup on exit
at_exit do
  puts 'Shutting down... cleaning up child processes.'

  $recorder&.cleanup

  if $listener_pid
    begin
      Process.kill('KILL', $listener_pid)
      puts "Stopped listener process #{$listener_pid}."
    rescue Errno::ESRCH
      # Process already finished
    end
  end
end

# Middleware
before do
  response.headers['Access-Control-Allow-Origin']  = '*'
  response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
  response['Access-Control-Allow-Origin'] = '*'

  @logger = Logger.new($stdout)
  content_type 'application/json;charset=utf8'
end

options '*' do
  200
end

not_found do
  status 404
  '404'
end

# ===================
# CORE ROUTES
# ===================

get '/' do
  { message: 'Sinatra is ok' }.to_json
end

# ===================
# AUDIO ROUTES
# ===================

post '/start_recording' do
  begin
    # Initialize recorder if needed
    $recorder ||= Audio::Recorder.new(RECORDINGS_DIR, @logger)

    if $recorder.recording?
      status 409
      return { error: 'Recording is already in progress.' }.to_json
    end

    # Kill wake-word listener if running
    if $listener_pid
      begin
        Process.kill('KILL', $listener_pid)
        @logger.info "Stopped listener process #{$listener_pid}."
      rescue Errno::ESRCH
        # Process already finished
      end
      $listener_pid = nil
    end

    # Start recording
    result = $recorder.start

    # Create WebSocket manager
    ws_manager = Core::WebSocketManager.new(settings.sockets, @logger)

    # Create transcriber
    transcriber = Audio::Transcriber.new(WHISPER_URL, @logger)

    # Wait for completion in background thread
    $recorder.wait_for_completion(lambda do |filepath|
      # Notify processing started
      ws_manager.broadcast({ event: 'process_recording' })

      # Transcribe
      transcription = transcriber.transcribe(filepath)

      # Broadcast result
      ws_manager.broadcast({
        event: 'recording_finished',
        message: 'Recording stopped.',
        output: transcription[:text]
      })
    end)

    result.to_json
  rescue StandardError => e
    @logger.error "Error starting recording: #{e.message}"
    status 500
    { error: "An unexpected error occurred: #{e.message}" }.to_json
  end
end

post '/stop_recording' do
  begin
    $recorder ||= Audio::Recorder.new(RECORDINGS_DIR, @logger)
    result = $recorder.stop
    result.to_json
  rescue StandardError => e
    @logger.error "Error stopping recording: #{e.message}"
    status 500
    { error: e.message }.to_json
  end
end

get '/is_recording' do
  $recorder ||= Audio::Recorder.new(RECORDINGS_DIR, @logger)

  if $recorder.recording?
    { message: 'recording', current_file: $recorder.filepath }.to_json
  else
    { message: 'idle' }.to_json
  end
end

post '/test_record' do
  begin
    $recorder ||= Audio::Recorder.new(RECORDINGS_DIR, @logger)

    if $recorder.recording?
      status 409
      return { error: 'Recording is already in progress.' }.to_json
    end

    result = $recorder.test_record

    if result[:exists]
      transcriber = Audio::Transcriber.new(WHISPER_URL, @logger)
      transcription = transcriber.transcribe(result[:filepath])

      {
        message: 'Test recording completed',
        transcription: transcription[:text],
        file: result[:filepath]
      }.to_json
    else
      @logger.warn 'Recording file was not created.'
      status 500
      { error: 'Recording file was not created.' }.to_json
    end
  rescue StandardError => e
    @logger.error "Error during test recording: #{e.message}"
    status 500
    { error: "Test recording failed: #{e.message}" }.to_json
  end
end

# ===================
# LLM ROUTES
# ===================

post '/llm/generate' do
  begin
    data = JSON.parse(request.body.read)
    llm = LLM::Gateway.new(OLLAMA_URL, @logger)

    result = llm.generate(
      model: data['model'] || 'gemma3:1b',
      prompt: data['prompt'],
      stream: data['stream'] || false,
      keep_alive: data['keep_alive'] || -1
    )

    result.to_json
  rescue StandardError => e
    @logger.error "Error calling LLM: #{e.message}"
    status 500
    { error: e.message }.to_json
  end
end

get '/llm/models' do
  begin
    llm = LLM::Gateway.new(OLLAMA_URL, @logger)
    llm.models.to_json
  rescue StandardError => e
    @logger.error "Error fetching models: #{e.message}"
    status 500
    { error: e.message }.to_json
  end
end

get '/llm/health' do
  llm = LLM::Gateway.new(OLLAMA_URL, @logger)
  {
    healthy: llm.health_check,
    url: OLLAMA_URL
  }.to_json
end

# ===================
# WAKE-WORD ROUTES
# ===================

post '/spawn-listener' do
  unless $listener_pid
    $listener_pid = Process.spawn('python3 backend/awaker.py')
    Process.detach($listener_pid)
    @logger.info "Spawning listener: #{$listener_pid}"
  end

  { message: 'listener spawned' }.to_json
end

post '/wake' do
  if $listener_pid
    begin
      Process.kill('KILL', $listener_pid)
    rescue StandardError
      nil
    end
    $listener_pid = nil
  end

  ws_manager = Core::WebSocketManager.new(settings.sockets, @logger)
  ws_manager.broadcast({ event: 'wake_word_received' })

  { message: 'wake word received' }.to_json
end

# ===================
# WEBSOCKET
# ===================

get '/ws' do
  if !request.websocket?
    status 426
    body 'WebSocket connection required'
  else
    request.websocket do |ws|
      ws_manager = Core::WebSocketManager.new(settings.sockets, @logger)

      ws.onopen do
        ws_manager.add_client(ws)
      end

      ws.onmessage do |msg|
        @logger.info "[WebSocket] 📨 Received message: #{msg}"
      end

      ws.onclose do
        ws_manager.remove_client(ws)
      end
    end
  end
end

# ===================
# UNUSED/LEGACY ROUTES
# ===================

# TTS route (abandoned, left for reference)
post '/speak' do
  request.body.rewind
  data = JSON.parse(request.body.read)
  text_to_speak = data['content']

  `amixer set Master 20% && echo "#{text_to_speak}" | piper --model en_US-amy-medium --output-raw | aplay -r 22050 -f S16_LE -t raw -`

  @logger.info "Spoke text: #{text_to_speak}"
  { message: 'ok' }.to_json
end
