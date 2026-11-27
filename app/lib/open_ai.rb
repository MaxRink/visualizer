class OpenAi
  class NotConfigured < StandardError; end

  # OPENAI_BASE_URL points the lookup at another OpenAI-compatible gateway
  # (e.g. an in-cluster LiteLLM). Plain HTTP is only allowed to a private
  # address, so the key never crosses a public network in cleartext. Without a
  # key the lookup reports NotConfigured and the UI hides the button.
  DEFAULT_BASE_URL = "https://api.openai.com/v1".freeze
  DEFAULT_MODEL = "auto/fast".freeze
  SYSTEM_PROMPT = Rails.root.join("app/prompts/coffee_bag_scraper.txt").read.freeze
  # Gateway throttling (429), provider overload (503/529) and short outages are
  # retried with a growing pause; anything else fails at once.
  RETRYABLE_CODES = %w[429 500 502 503 504 529].freeze
  MAX_ATTEMPTS = 3

  def self.api_key
    ENV["OPENAI_API_KEY"].presence || Rails.application.credentials.dig(:open_ai, :api_key).presence
  end

  def self.configured?
    api_key.present?
  end

  def self.base_url
    ENV["OPENAI_BASE_URL"].presence || DEFAULT_BASE_URL
  end

  def self.model
    ENV["OPENAI_MODEL"].presence || DEFAULT_MODEL
  end

  def self.endpoint
    "#{base_url.chomp("/")}/chat/completions"
  end

  def message(content, attempt: 1)
    raise NotConfigured, "Coffee info lookup is not configured on this instance." unless self.class.configured?

    uri = URI(self.class.endpoint)
    raise ArgumentError, "OPENAI_BASE_URL must be HTTPS or a private HTTP address" unless SystemOne.secure_or_private?(uri)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    request = Net::HTTP::Post.new(uri.request_uri)
    request["Authorization"] = "Bearer #{self.class.api_key}"
    request["Content-Type"] = "application/json"
    request.body = {
      model: self.class.model,
      max_tokens: 500,
      messages: [
        {role: "system", content: SYSTEM_PROMPT},
        {role: "user", content:}
      ]
    }.to_json

    response = http.request(request)
    unless response.is_a?(Net::HTTPSuccess)
      # Status only: the gateway's error body can echo request details and is
      # broadcast to the browser by CoffeeBagScrapeJob.
      request_id = response["x-request-id"]
      suffix = request_id.present? ? " (request_id: #{request_id})" : ""
      raise "Failed to get an inference response: #{response.code}#{suffix}"
    end

    JSON.parse(response.body).dig("choices", 0, "message", "content").to_s
  rescue StandardError
    raise if attempt >= MAX_ATTEMPTS || RETRYABLE_CODES.exclude?(response&.code)

    sleep(2**attempt)
    attempt += 1
    retry
  end
end
