# LLM Gateway module
# Wrapper for Ollama API interactions

require 'net/http'
require 'json'

module LLM
  class Gateway
    def initialize(ollama_url, logger)
      @ollama_url = ollama_url
      @logger = logger
    end

    def generate(model:, prompt:, stream: false, keep_alive: -1)
      @logger.info "[LLM] 💬 Calling Ollama (model: #{model}, stream: #{stream})"
      start_time = Time.now

      uri = URI("#{@ollama_url}/api/generate")
      request = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
      request.body = {
        model: model,
        prompt: prompt,
        stream: stream,
        keep_alive: keep_alive
      }.to_json

      response = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(request)
      end

      duration = (Time.now - start_time).round(2)

      if response.is_a?(Net::HTTPSuccess)
        result = JSON.parse(response.body)
        response_text = result['response'] || ''
        @logger.info "[LLM] ✅ Response received in #{duration}s (#{response_text.length} chars)"

        {
          success: true,
          response: response_text,
          model: model,
          duration: duration
        }
      else
        @logger.error "[LLM] ❌ Request failed: #{response.code} #{response.message}"
        {
          success: false,
          error: "HTTP #{response.code}: #{response.message}",
          duration: duration
        }
      end
    rescue StandardError => e
      duration = (Time.now - start_time).round(2)
      @logger.error "[LLM] ❌ Error: #{e.message}"
      {
        success: false,
        error: e.message,
        duration: duration
      }
    end

    def models
      uri = URI("#{@ollama_url}/api/tags")
      response = Net::HTTP.get_response(uri)

      if response.is_a?(Net::HTTPSuccess)
        JSON.parse(response.body)
      else
        { error: "Failed to fetch models" }
      end
    rescue StandardError => e
      @logger.error "[LLM] ❌ Error fetching models: #{e.message}"
      { error: e.message }
    end

    def health_check
      uri = URI("#{@ollama_url}/api/tags")
      response = Net::HTTP.get_response(uri)
      response.is_a?(Net::HTTPSuccess)
    rescue StandardError
      false
    end
  end
end
