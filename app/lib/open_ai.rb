class OpenAi
  class NotConfigured < StandardError; end

  API_ENDPOINT = "https://api.openai.com/v1/responses".freeze
  MODEL = "gpt-6-luna".freeze
  SYSTEM_PROMPT = Rails.root.join("app/prompts/coffee_bag_scraper.txt").read.freeze

  def self.api_key
    ENV["OPENAI_API_KEY"].presence || Rails.application.credentials.dig(:open_ai, :api_key).presence
  end

  def self.configured?
    api_key.present?
  end

  def message(content, attempt: 1)
    raise NotConfigured, "Coffee info lookup is not configured on this instance." unless self.class.configured?

    uri = URI(API_ENDPOINT)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.request_uri)
    request["Authorization"] = "Bearer #{self.class.api_key}"
    request["Content-Type"] = "application/json"
    request.body = {
      model: MODEL,
      max_output_tokens: 500,
      reasoning: {effort: "none"},
      input: [
        {role: "system", content: SYSTEM_PROMPT},
        {role: "user", content:}
      ]
    }.to_json

    response = http.request(request)
    unless response.is_a?(Net::HTTPSuccess)
      details = response.body.presence || response.message
      request_id = response["x-request-id"]
      suffix = request_id.present? ? " (request_id: #{request_id})" : ""
      raise "Failed to get response from OpenAI: #{response.code} #{details}#{suffix}"
    end

    model_response = JSON.parse(response.body)
    model_response["output"].filter_map { it["content"] }.first.first["text"]
  rescue StandardError
    raise if attempt >= 3 || response&.code != "529"

    attempt += 1
    retry
  end
end
