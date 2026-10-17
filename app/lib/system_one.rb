require "ipaddr"
require "net/http"

class SystemOne
  class Error < StandardError; end

  RETRYABLE_CODES = %w[408 429 500 502 503 504].freeze
  MAX_ATTEMPTS = 3
  MAX_REQUEST_BYTES = 128 * 1024
  MAX_RESPONSE_BYTES = 64 * 1024
  MAX_COMPLETION_TOKENS = 512

  def initialize(api_endpoint: ENV.fetch("VISUALIZER_INFERENCE_BASE_URL"), model: ENV.fetch("VISUALIZER_INFERENCE_MODEL"), api_key: ENV.fetch("VISUALIZER_INFERENCE_API_KEY"))
    @uri = validated_uri(api_endpoint)
    @model = model
    @api_key = api_key
    raise Error, "VISUALIZER_INFERENCE_MODEL is empty" if @model.blank?
    raise Error, "VISUALIZER_INFERENCE_API_KEY is empty" if @api_key.blank?
  end

  def evaluate(state:, questions:)
    request_body = {
      model: @model,
      messages: [
        {role: "system", content: "Answer the supplied espresso questions using only the supplied shot state. Return one JSON object with an answers object; do not include markdown."},
        {role: "user", content: {state: state, questions: questions}.to_json}
      ],
      response_format: {type: "json_object"},
      temperature: 0,
      max_tokens: MAX_COMPLETION_TOKENS
    }.to_json
    raise Error, "LiteLLM request exceeded the configured size limit" if request_body.bytesize > MAX_REQUEST_BYTES

    response = request_with_retry(request_body)
    result = JSON.parse(response.dig("choices", 0, "message", "content"))
    raise Error, "LiteLLM response did not include answers" unless result["answers"].is_a?(Hash)

    result.merge("model" => @model)
  rescue JSON::ParserError, TypeError
    raise Error, "LiteLLM returned an invalid JSON response"
  end

  private

  def validated_uri(value)
    uri = URI.parse(value)
    valid_scheme = uri.is_a?(URI::HTTPS) || (uri.is_a?(URI::HTTP) && private_ip?(uri.host))
    unless valid_scheme && uri.path == "/v1/chat/completions" && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?
      raise Error, "VISUALIZER_INFERENCE_BASE_URL must be HTTPS or a private HTTP Chat Completions endpoint"
    end

    uri
  rescue URI::InvalidURIError
    raise Error, "VISUALIZER_INFERENCE_BASE_URL is invalid"
  end

  def private_ip?(host)
    IPAddr.new(host).private?
  rescue IPAddr::InvalidAddressError
    false
  end

  def request_with_retry(body)
    attempt = 0
    loop do
      attempt += 1
      status, response_body = post(body)
      return JSON.parse(response_body) if status.between?(200, 299)
      raise Error, "LiteLLM HTTP #{status}" if attempt >= MAX_ATTEMPTS || RETRYABLE_CODES.exclude?(status.to_s)

      sleep(2**(attempt - 1))
    rescue Net::OpenTimeout, Net::ReadTimeout, EOFError, SocketError => error
      raise Error, "LiteLLM request failed (#{error.class})" if attempt >= MAX_ATTEMPTS

      sleep(2**(attempt - 1))
    end
  end

  def post(body)
    request = Net::HTTP::Post.new(@uri)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Content-Type"] = "application/json"
    request.body = body

    status = nil
    response_body = +""
    http = Net::HTTP.new(@uri.host, @uri.port)
    http.use_ssl = @uri.is_a?(URI::HTTPS)
    http.open_timeout = 5
    http.read_timeout = 30
    http.write_timeout = 10
    http.start do |connection|
      connection.request(request) do |response|
        status = response.code.to_i
        response.read_body do |chunk|
          response_body << chunk
          raise Error, "LiteLLM response exceeded the configured size limit" if response_body.bytesize > MAX_RESPONSE_BYTES
        end
      end
    end
    [status, response_body]
  end
end
