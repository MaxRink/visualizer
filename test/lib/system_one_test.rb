require "test_helper"

class SystemOneTest < ActiveSupport::TestCase
  ENDPOINT = "http://10.255.255.254:30681/v1/chat/completions"

  test "uses configured OpenAI-compatible model and parses answers" do
    response = {choices: [{message: {content: {answers: {relative_0: {type: "score", probabilities: {"1" => 1.0}}}}.to_json}}]}.to_json
    request = stub_request(:post, ENDPOINT).with do |http_request|
      body = JSON.parse(http_request.body)
      http_request.headers["Authorization"] == "Bearer synthetic-key" &&
        body["model"] == "coffee-bag-vision" &&
        body["max_tokens"] == SystemOne::MAX_COMPLETION_TOKENS &&
        body["response_format"] == {"type" => "json_object"} &&
        body["messages"].last["content"].include?("synthetic shot")
    end.to_return(status: 200, body: response)

    result = client.evaluate(state: {note: "synthetic shot"}, questions: ["relative_0"])

    assert_requested(request)
    assert_equal "coffee-bag-vision", result.fetch("model")
    assert_equal({"type" => "score", "probabilities" => {"1" => 1.0}}, result.dig("answers", "relative_0"))
  end

  test "rejects public plain HTTP and URL credentials or query strings" do
    [
      "http://example.com/v1/chat/completions",
      "http://user:password@192.168.1.104/v1/chat/completions",
      "https://example.com/v1/chat/completions?redirect=1",
      "https://example.com/other"
    ].each do |endpoint|
      assert_raises(SystemOne::Error) { client(api_endpoint: endpoint) }
    end
  end

  test "caps request size before making a network request" do
    error = assert_raises(SystemOne::Error) do
      client.evaluate(state: {note: "x" * SystemOne::MAX_REQUEST_BYTES}, questions: [])
    end

    assert_includes error.message, "size limit"
    assert_not_requested(:post, ENDPOINT)
  end

  test "caps streamed response size" do
    stub_request(:post, ENDPOINT).to_return(status: 200, body: "x" * (SystemOne::MAX_RESPONSE_BYTES + 1))

    error = assert_raises(SystemOne::Error) { client.evaluate(state: {}, questions: []) }

    assert_includes error.message, "size limit"
  end

  test "does not include upstream response content in errors or follow redirects" do
    private_target = "http://192.168.1.105/v1/chat/completions"
    stub_request(:post, ENDPOINT).to_return(status: 302, headers: {"Location" => private_target}, body: "private response details")

    error = assert_raises(SystemOne::Error) { client.evaluate(state: {}, questions: []) }

    assert_equal "LiteLLM HTTP 302", error.message
    assert_not_requested(:post, private_target)
  end

  test "retries transient failures only within the bounded attempt count" do
    stub_request(:post, ENDPOINT).to_return(status: 503, body: "untrusted detail")

    error = assert_raises(SystemOne::Error) { client.evaluate(state: {}, questions: []) }
    assert_equal "LiteLLM HTTP 503", error.message

    assert_requested(:post, ENDPOINT, times: SystemOne::MAX_ATTEMPTS)
  end

  private

  def client(api_endpoint: ENDPOINT)
    SystemOne.new(api_endpoint: api_endpoint, model: "coffee-bag-vision", api_key: "synthetic-key")
  end
end
