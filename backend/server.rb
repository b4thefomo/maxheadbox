require 'sinatra'
require 'json'
require 'open3'
require 'sinatra-websocket'
require 'net/http'
require 'rest-client'
require 'uri'
require 'shellwords'
require 'dotenv'

Dotenv.load('.env.local', '.env')

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

  command = "rec -c 1 -r 16000 #{Shellwords.escape(filepath)} silence 1 0.1 1% 1 1.0 1%"

  begin
    pid = Process.spawn(command)

    $recording_pid = pid
    $current_recording_file = filepath
    @logger.info "Started recording (PID: #{$recording_pid}) to #{filepath}"

    Thread.new do
      @logger.info "Waiting for process #{$recording_pid} to finish..."
      Process.wait($recording_pid)
      @logger.info "Process #{$recording_pid} finished. Starting transcription..."

      settings.sockets.each do |s|
        s.send({
          event: 'process_recording'
        }.to_json)
      end

      if File.exist?(filepath)
        segments = transcribe_file(filepath)
        message_output = ''
        segments.each do |s|
          message_output += s['text']
        end

        settings.sockets.each do |s|
          s.send({
            event: 'recording_finished',
            message: 'Recording stopped.',
            output: message_output
          }.to_json)
        end
        @logger.info 'Sent recording_finished event via WebSocket.'
      else
        @logger.warn 'Recording file was not found after process finished.'
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

get '/ws' do
  if !request.websocket?
    status 426
    body 'WebSocket connection required'
  else
    request.websocket do |ws|
      settings.sockets << ws

      ws.onopen do
        @logger.info 'WebSocket opened'
      end

      ws.onmessage do |msg|
        @logger.info "Received message: #{msg}"
      end

      ws.onclose do
        settings.sockets.delete(ws)
        @logger.info 'WebSocket closed'
      end
    end
  end
end

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
