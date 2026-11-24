require "test_helper"

class CoffeeBagScraperTest < ActiveSupport::TestCase
  test "identifies multicast addresses" do
    assert IPAddr.new("224.0.0.1").multicast?
    assert IPAddr.new("ff00::1").multicast?
    assert_not IPAddr.new("8.8.8.8").multicast?
  end

  test "rejects private addresses" do
    scraper = CoffeeBagScraper.new(create(:user), "http://127.0.0.1", "request-id")

    error = assert_raises(ArgumentError) { scraper.__send__(:page_content, "http://127.0.0.1") }

    assert_equal "URL must resolve to a public IP address", error.message
  end

  test "rejects redirects to private addresses" do
    scraper = CoffeeBagScraper.new(create(:user), "https://93.184.216.34", "request-id")
    stub_request(:get, "https://93.184.216.34/").to_return(status: 302, headers: {"Location" => "http://127.0.0.1/secret"})

    assert_raises(ArgumentError) { scraper.__send__(:page_content, "https://93.184.216.34") }
  end

  test "falls back to crawlbase when connection times out" do
    scraper = CoffeeBagScraper.new(create(:user), "https://93.184.216.34", "request-id")
    stub_request(:get, "https://93.184.216.34/").to_timeout
    scraper.define_singleton_method(:crawlbase_content) { |_url| "crawlbase content" }

    assert_equal "crawlbase content", scraper.__send__(:page_content, "https://93.184.216.34")
  end

  test "parse_bag accepts a JSON object" do
    assert_equal({"name" => "Kenya"}, CoffeeBagScraper.parse_bag('{"name":"Kenya"}'))
  end

  test "parse_bag rejects a JSON string" do
    assert_raises(ArgumentError) { CoffeeBagScraper.parse_bag('"plain text"') }
  end

  test "parse_bag rejects a JSON array" do
    assert_raises(ArgumentError) { CoffeeBagScraper.parse_bag("[1, 2]") }
  end

  test "raises NotConfigured when the lookup is not configured" do
    without_env do
      assert_raises(CoffeeBagScraper::NotConfigured) do
        CoffeeBagScraper.new(create(:user), "https://example.com", "request-id").scrape
      end
    end
  end

  test "uses environment keys and the downloader without network" do
    with_env("CRAWLBASE_TOKEN" => "crawlbase-token", "OPENAI_API_KEY" => "openai-key") do
      scraper = CoffeeBagScraper.new(create(:user), "https://example.com", "request-id")
      scraper.define_singleton_method(:page_content) { |*, **| "page text" }
      fake = Object.new
      fake.define_singleton_method(:message) { |*| '{"name":"Kenya"}' }
      original = OpenAi.method(:new)
      OpenAi.define_singleton_method(:new) { |**| fake }

      assert_equal({"name" => "Kenya"}, scraper.scrape)
    ensure
      OpenAi.define_singleton_method(:new, original)
    end
  end

  test "the scrape job broadcasts the actionable message when not configured" do
    user = create(:user)

    assert_broadcast_on(CoffeeBagScraperChannel.broadcasting_for(user), {request_id: "request-id", error: "Coffee info lookup is not configured on this instance."}) do
      without_env { CoffeeBagScrapeJob.perform_now(user, "https://example.com", "request-id") }
    end
  end

  private

  ENV_KEYS = %w[CRAWLBASE_TOKEN OPENAI_API_KEY].freeze

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
