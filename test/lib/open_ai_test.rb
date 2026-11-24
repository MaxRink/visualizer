require "test_helper"

class OpenAiTest < ActiveSupport::TestCase
  ENV_KEYS = %w[OPENAI_API_KEY OPENAI_BASE_URL OPENAI_MODEL].freeze

  test "defaults to the LiteLLM gateway and the auto/fast group" do
    without_env do
      assert_equal "http://192.168.1.104:30681/v1", OpenAi.base_url
      assert_equal "auto/fast", OpenAi.model
      assert_equal "http://192.168.1.104:30681/v1/chat/completions", OpenAi.endpoint
      assert_not OpenAi.configured?
    end
  end

  test "base url and model come from the environment" do
    with_env("OPENAI_BASE_URL" => "https://api.openai.com/v1/", "OPENAI_MODEL" => "gpt-6-luna") do
      assert_equal "https://api.openai.com/v1/chat/completions", OpenAi.endpoint
      assert_equal "gpt-6-luna", OpenAi.model
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
