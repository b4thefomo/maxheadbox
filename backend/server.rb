require 'sinatra'
require 'json'
require 'open3'
require 'sinatra-websocket'
require 'net/http'
require 'rest-client'
require 'uri'
require 'shellwords'
require 'dotenv'

Dotenv.load(File.join(File.dirname(__FILE__), '..', '.env.local'), File.join(File.dirname(__FILE__), '..', '.env'))

set :server, 'thin'
set :sockets, []
set :threaded, true

RECORDINGS_DIR = File.expand_path(ENV['RECORDINGS_DIR'], File.dirname(__FILE__))
FileUtils.mkdir_p(RECORDINGS_DIR) unless Dir.exist?(RECORDINGS_DIR)

$recording_pid = nil
$listener_pid = nil
$current_recording_file = nil

at_exit do
  puts 'Shutting down... cleaning up child processes.'

  if $recording_pid
    begin
      Process.kill('TERM', $recording_pid)
      puts "Stopped recording process #{$recording_pid}."
    rescue Errno::ESRCH
    end
  end

  if $listener_pid
    begin
      Process.kill('KILL', $listener_pid)
      puts "Stopped listener process #{$listener_pid}."
    rescue Errno::ESRCH
    end
  end
end

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

get '/' do
  { message: 'Sinatra is ok' }.to_json
end

# unused route for now kind of abandoned the idea of using a TTS model
# I just left it here for future reference
post '/speak' do
  request.body.rewind
  data = JSON.parse(request.body.read)
  text_to_speak = data['content']

  `amixer set Master 20% && echo "#{text_to_speak}" | piper --model en_US-amy-medium --output-raw | aplay -r 22050 -f S16_LE -t raw -`

  @logger.info "Spoke text: #{text_to_speak}"
  { message: 'ok' }.to_json
end

post '/start_recording' do
  if is_recording?
    status 409 # Conflict
    return { error: 'Recording is already in progress.' }.to_json
  end

  if $listener_pid
    begin
      Process.kill('KILL', $listener_pid)
      @logger.info "Stopped listener process #{$listener_pid}."
    rescue Errno::ESRCH
    end
  end

  filename = 'recording.wav'
  filepath = File.join(RECORDINGS_DIR, filename)

  # Add timeout to force stop after 10 seconds, with more aggressive silence detection
  command = "timeout 10 sox -t alsa hw:0,0 -c 1 -r 16000 #{Shellwords.escape(filepath)} gain 20 silence 1 0.3 2% 1 2.0 2%"

  begin
    @logger.info "[Recording] 🎤 Starting new recording..."
    pid = Process.spawn(command)

    $recording_pid = pid
    $current_recording_file = filepath
    @logger.info "[Recording] ✅ Started (PID: #{$recording_pid}) file: #{filepath}"

    Thread.new do
      start_time = Time.now
      @logger.info "[Recording] Waiting for process #{$recording_pid} to finish..."
      Process.wait($recording_pid)
      duration = (Time.now - start_time).round(2)
      file_size = File.exist?(filepath) ? (File.size(filepath) / 1024.0).round(1) : 0
      @logger.info "[Recording] ⏹️  Finished after #{duration}s, file size: #{file_size}KB"

      settings.sockets.each do |s|
        s.send({
          event: 'process_recording'
        }.to_json)
      end

      if File.exist?(filepath)
        @logger.info "[Transcription] 📝 Calling Whisper service..."
        transcribe_start = Time.now
        segments = transcribe_file(filepath)
        transcribe_duration = (Time.now - transcribe_start).round(2)

        message_output = ''
        segments.each do |s|
          message_output += s['text']
        end

        if message_output.strip.empty?
          @logger.info "[Transcription] ✅ Completed in #{transcribe_duration}s → (empty - silence detected)"
        else
          @logger.info "[Transcription] ✅ Completed in #{transcribe_duration}s → \"#{message_output.strip}\""
        end

        settings.sockets.each do |s|
          s.send({
            event: 'recording_finished',
            message: 'Recording stopped.',
            output: message_output
          }.to_json)
        end
        @logger.info "[WebSocket] 📤 Sent recording_finished event to #{settings.sockets.length} client(s)"
      else
        @logger.error "[Recording] ❌ File not found after process finished: #{filepath}"
        settings.sockets.each do |s|
          s.send({
            event: 'recording_error',
            error: 'Recording stopped, but the output file was not found.'
          }.to_json)
        end
      end

      $recording_pid = nil
      $current_recording_file = nil
    end

    { message: 'Recording started.', filename: filename, filepath: filepath }.to_json
  rescue Errno::ENOENT => e
    @logger.info "Error starting recording: #{e.message}"
    status 500
    { error: "Failed to start recording. Is 'arecord' installed and in PATH? #{e.message}" }.to_json
  rescue StandardError => e
    @logger.info "Unexpected error starting recording: #{e.message}"
    status 500
    { error: "An unexpected error occurred: #{e.message}" }.to_json
  end
end

post '/stop_recording' do
  unless is_recording?
    status 400
    return { error: 'No recording is currently in progress.' }.to_json
  end

  begin
    # Send SIGINT (Ctrl+C) to gracefully stop the recording process
    Process.kill('INT', $recording_pid)
    @logger.info "Sent SIGINT to PID #{$recording_pid}."

    { message: 'Manual stop initiated.' }.to_json
  rescue Errno::ESRCH
    @logger.info "Process #{$recording_pid} not found. It might have already finished or crashed."
    status 500
    { error: 'Recording process already finished or not found.' }.to_json
  rescue StandardError => e
    @logger.info "Error stopping recording for PID #{$recording_pid}: #{e.message}"
    status 500
    { error: "An unexpected error occurred: #{e.message}" }.to_json
  end
end

get '/is_recording' do
  if is_recording?
    { message: 'recording', current_file: $current_recording_file }.to_json
  else
    { message: 'idle' }.to_json
  end
end

post '/test_record' do
  if is_recording?
    status 409
    return { error: 'Recording is already in progress.' }.to_json
  end

  filename = 'test_recording.wav'
  filepath = File.join(RECORDINGS_DIR, filename)

  # Simple 5-second recording without silence detection, with volume boost
  command = "timeout 5 sox -t alsa hw:0,0 -c 1 -r 16000 #{Shellwords.escape(filepath)} gain 20"

  begin
    @logger.info "Starting test recording for 5 seconds..."
    pid = Process.spawn(command)
    $recording_pid = pid
    $current_recording_file = filepath

    # Wait for recording to finish
    Process.wait(pid)
    $recording_pid = nil
    @logger.info "Test recording finished."

    # Transcribe immediately
    if File.exist?(filepath)
      segments = transcribe_file(filepath)
      message_output = ''
      segments.each do |s|
        message_output += s['text']
      end

      @logger.info "Transcription: #{message_output}"
      {
        message: 'Test recording completed',
        transcription: message_output,
        file: filepath
      }.to_json
    else
      @logger.warn 'Recording file was not created.'
      status 500
      { error: 'Recording file was not created.' }.to_json
    end
  rescue StandardError => e
    $recording_pid = nil
    @logger.error "Error during test recording: #{e.message}"
    status 500
    { error: "Test recording failed: #{e.message}" }.to_json
  end
end

get '/ws' do
  if !request.websocket?
    status 426
    body 'WebSocket connection required'
  else
    request.websocket do |ws|
      settings.sockets << ws

      ws.onopen do
        @logger.info "[WebSocket] ✅ Client connected (total: #{settings.sockets.length})"
      end

      ws.onmessage do |msg|
        @logger.info "[WebSocket] 📨 Received message: #{msg}"
      end

      ws.onclose do
        settings.sockets.delete(ws)
        @logger.info "[WebSocket] ⚠️  Client disconnected (remaining: #{settings.sockets.length})"
      end
    end
  end
end

post '/spawn-listener' do
  unless $listener_pid
    $listener_pid = Process.spawn('python3 awaker.py')
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

  settings.sockets.each { |s| s.send({ event: 'wake_word_received' }.to_json) }

  { message: 'wake word received' }.to_json
end

Dir['./backend/notions/**/*.rb'].each { |f| require f }

def is_recording?
  !!$recording_pid
end

def transcribe_file(file_path)
  uri = URI('http://localhost:8000/transcribe')
  request = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
  request.body = { file_path: file_path }.to_json

  response = Net::HTTP.start(uri.hostname, uri.port) do |http|
    http.request(request)
  end

  JSON.parse(response.body)
end
