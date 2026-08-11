class RewriteText
  MODES = %w[correct professional concise friendly clear].freeze

  PROMPT = <<~TEXT.freeze
    You are a professional writing assistant. Rewrite the user text in exactly these modes:
    #{MODES.join(', ')}. Preserve meaning. Do not invent facts.
    Return only JSON in this shape:
    {"suggestions":[#{MODES.map { |m| %({"mode":"#{m}","text":"..."}) }.join(',')}]}
  TEXT

  def initialize(text:, client: Ai::GroqClient.new)
    @text = text
    @client = client
  end

  def call
    raw = @client.generate(system_prompt: PROMPT, user_prompt: @text)
    suggestions = parse(raw)

    MODES.map do |mode|
      match = suggestions.find { |s| s['mode'] == mode }
      raise Ai::Error, "model omitted mode=#{mode}" if match.nil?

      { mode: mode, text: match['text'].to_s }
    end
  end

  private

  def parse(raw)
    parsed = JSON.parse(raw)
    suggestions = parsed['suggestions']
    raise Ai::Error, 'model response missing "suggestions" array' unless suggestions.is_a?(Array)

    suggestions
  rescue JSON::ParserError => e
    raise Ai::Error, "model returned non-JSON: #{e.message}"
  end
end
