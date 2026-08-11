require 'net/http'
require 'json'

module Ai
  class Error < StandardError; end

  # Groq exposes an OpenAI-compatible chat-completions endpoint.
  class GroqClient
    URL = URI('https://api.groq.com/openai/v1/chat/completions').freeze
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 30

    # Returns the assistant's message content as a raw String.
    def generate(system_prompt:, user_prompt:)
      response = post(body(system_prompt, user_prompt))
      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "groq_http_#{response.code}: #{response.body.to_s[0, 500]}"
      end

      content = JSON.parse(response.body).dig('choices', 0, 'message', 'content')
      raise Error, 'groq returned no message content' if content.to_s.strip.empty?

      content
    end

    private

    def body(system_prompt, user_prompt)
      {
        model: ENV.fetch('GROQ_MODEL'),
        max_tokens: 1200,
        temperature: 0.2,
        # Guarantees parseable JSON — no markdown fences to strip.
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: system_prompt },
          { role: 'user', content: user_prompt }
        ]
      }.to_json
    end

    def post(payload)
      request = Net::HTTP::Post.new(URL)
      request['Authorization'] = "Bearer #{ENV.fetch('GROQ_API_KEY')}"
      request['Content-Type'] = 'application/json'
      request.body = payload

      Net::HTTP.start(URL.hostname, URL.port,
                      use_ssl: true,
                      open_timeout: OPEN_TIMEOUT,
                      read_timeout: READ_TIMEOUT) { |http| http.request(request) }
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise Error, "groq timeout: #{e.class}"
    end
  end
end
