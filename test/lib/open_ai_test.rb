require "test_helper"

class OpenAiTest < ActiveSupport::TestCase
  ENV_KEYS = %w[OPENAI_API_KEY OPENAI_BASE_URL OPENAI_MODEL].freeze

  test "defaults to the OpenAI API and the auto/fast group" do
    without_env do
      assert_equal "https://api.openai.com/v1", OpenAi.base_url
      assert_equal "auto/fast", OpenAi.model
      assert_equal "https://api.openai.com/v1/chat/completions", OpenAi.endpoint
      assert_not OpenAi.configured?
    end
  end

  test "base url and model come from the environment" do
    with_env("OPENAI_BASE_URL" => "https://api.openai.com/v1/", "OPENAI_MODEL" => "gpt-6-luna") do
      assert_equal "https://api.openai.com/v1/chat/completions", OpenAi.endpoint
      assert_equal "gpt-6-luna", OpenAi.model
    end
  end

  test "retries a throttled gateway response and returns the answer" do
    with_env("OPENAI_API_KEY" => "synthetic-key", "OPENAI_BASE_URL" => "http://10.255.255.254:30681/v1") do
      request = stub_request(:post, "http://10.255.255.254:30681/v1/chat/completions")
        .to_return({status: 429, body: "rate limited"}, {status: 200, body: {choices: [{message: {content: '{"name":"Kenya"}'}}]}.to_json})
      client = OpenAi.new
      client.define_singleton_method(:sleep) { |_seconds| nil }

      assert_equal '{"name":"Kenya"}', client.message("page text")
      assert_requested(request, times: 2)
    end
  end

  test "does not retry a client error" do
    with_env("OPENAI_API_KEY" => "synthetic-key", "OPENAI_BASE_URL" => "http://10.255.255.254:30681/v1") do
      request = stub_request(:post, "http://10.255.255.254:30681/v1/chat/completions").to_return(status: 400, body: "bad request")

      error = assert_raises(RuntimeError) { OpenAi.new.message("page text") }

      assert_match "400", error.message
      assert_no_match "bad request", error.message
      assert_requested(request, times: 1)
    end
  end

  test "refuses to send the key over plain HTTP to a public address" do
    with_env("OPENAI_API_KEY" => "synthetic-key", "OPENAI_BASE_URL" => "http://203.0.113.10/v1") do
      error = assert_raises(ArgumentError) { OpenAi.new.message("page text") }

      assert_match "OPENAI_BASE_URL", error.message
      assert_not_requested(:post, "http://203.0.113.10/v1/chat/completions")
    end
  end

  private

  def without_env
    previous = ENV_KEYS.index_with { |key| ENV[key] }
    ENV_KEYS.each { |key| ENV.delete(key) }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end

  def with_env(values)
    previous = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end
end
