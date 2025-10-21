# Audio transcription module
# Client for Whisper transcription service

require 'net/http'
require 'json'

module Audio
  class Transcriber
    def initialize(whisper_url, logger)
      @whisper_url = whisper_url
      @logger = logger
    end

    def transcribe(file_path)
      @logger.info "[Transcription] 📝 Calling Whisper service..."
      transcribe_start = Time.now

      uri = URI("#{@whisper_url}/transcribe")
      request = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
      request.body = { file_path: file_path }.to_json

      response = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(request)
      end

      segments = JSON.parse(response.body)
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

      {
        segments: segments,
        text: message_output,
        duration: transcribe_duration
      }
    rescue StandardError => e
      @logger.error "[Transcription] ❌ Error: #{e.message}"
      {
        segments: [],
        text: '',
        duration: 0,
        error: e.message
      }
    end
  end
end
