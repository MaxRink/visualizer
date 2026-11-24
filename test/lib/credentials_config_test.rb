require "test_helper"

class CredentialsConfigTest < ActiveSupport::TestCase
  ENV_KEYS = %w[
    AIRTABLE_CLIENT_ID AIRTABLE_CLIENT_SECRET
    WEBPUSH_PUBLIC_KEY WEBPUSH_PRIVATE_KEY
    OPENAI_API_KEY CRAWLBASE_TOKEN
    CREEM_API_KEY CREEM_WEBHOOK_SECRET CREEM_PRODUCT_ID CREEM_PRODUCT_ID_TRIAL
    LEMON_SQUEEZY_API_KEY LEMON_SQUEEZY_WEBHOOK_SECRET
    TURNSTILE_SITE_KEY TURNSTILE_SECRET_KEY
    LOFFEE_LABS_API_KEY
  ].freeze

  test "every accessor returns nil instead of raising when nothing is configured" do
    without_env do
      assert_nil AirtableConfig.client_id
      assert_nil AirtableConfig.client_secret
      assert_not AirtableConfig.configured?

      assert_nil WebPushConfig.public_key
      assert_nil WebPushConfig.private_key
      assert_not WebPushConfig.configured?

      assert_nil OpenAi.api_key
      assert_not OpenAi.configured?

      assert_nil CoffeeBagScraper.crawlbase_token
      assert_not CoffeeBagScraper.configured?

      assert_nil Creem.api_key
      assert_nil Creem.webhook_secret
      assert_nil Creem.product_id
      assert_nil Creem.product_id_trial
      assert_not Creem.configured?

      assert_nil LemonSqueezy.api_key
      assert_nil LemonSqueezy.webhook_secret
      assert_not LemonSqueezy.configured?

      assert_nil TurnstileConfig.site_key
      assert_nil TurnstileConfig.secret_key
      assert_not TurnstileConfig.configured?

      assert_nil LoffeeLabsImporterJob.api_key
    end
  end

  test "environment variables win over credentials" do
    with_env(
      "AIRTABLE_CLIENT_ID" => "airtable-id",
      "WEBPUSH_PUBLIC_KEY" => "push-key",
      "OPENAI_API_KEY" => "openai-key",
      "CRAWLBASE_TOKEN" => "crawlbase-token",
      "CREEM_API_KEY" => "creem-key",
      "LEMON_SQUEEZY_API_KEY" => "lemon-key",
      "TURNSTILE_SITE_KEY" => "turnstile-key",
      "LOFFEE_LABS_API_KEY" => "loffee-key"
    ) do
      assert_equal "airtable-id", AirtableConfig.client_id
      assert_equal "push-key", WebPushConfig.public_key
      assert_equal "openai-key", OpenAi.api_key
      assert_equal "crawlbase-token", CoffeeBagScraper.crawlbase_token
      assert_equal "creem-key", Creem.api_key
      assert_equal "lemon-key", LemonSqueezy.api_key
      assert_equal "turnstile-key", TurnstileConfig.site_key
      assert_equal "loffee-key", LoffeeLabsImporterJob.api_key
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
