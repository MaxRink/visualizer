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
    stub_fetch(scraper, CoffeeBagScraper::Page.new(status: 302, body: "", location: "http://127.0.0.1/secret"))

    assert_raises(ArgumentError) { scraper.__send__(:page_content, "https://93.184.216.34") }
  end

  test "falls back to crawlbase when the page does not respond and a token is set" do
    scraper = CoffeeBagScraper.new(create(:user), "https://93.184.216.34", "request-id")
    stub_fetch(scraper, nil)
    scraper.define_singleton_method(:crawlbase_content) { |_url, _page| "crawlbase content" }

    assert_equal "crawlbase content", scraper.__send__(:page_content, "https://93.184.216.34")
  end

  test "a blocked page without crawlbase raises a clear error instead of not configured" do
    without_env do
      scraper = CoffeeBagScraper.new(create(:user), "https://93.184.216.34", "request-id")
      stub_fetch(scraper, CoffeeBagScraper::Page.new(status: 429, body: "Too Many Requests", location: nil))

      error = assert_raises(CoffeeBagScraper::Unavailable) { scraper.__send__(:page_content, "https://93.184.216.34") }

      assert_equal "The roaster's website blocked the lookup (HTTP 429). Enter the details manually.", error.message
    end
  end

  test "uses JSON-LD and Open Graph data of a page that renders in JavaScript" do
    html = <<~HTML
      <html><head>
        <meta property="og:title" content="Apas Espresso">
        <meta property="og:description" content="Washed Ethiopian coffee with notes of peach">
        <script type="application/ld+json">{"@type":"Product","name":"Apas Espresso","brand":"Kaffeemacher"}</script>
        <script type="application/ld+json">{"@type":"Organization","name":"Shop"}</script>
      </head><body><div id="app"></div><script>render()</script></body></html>
    HTML
    scraper = CoffeeBagScraper.new(create(:user), "https://93.184.216.34", "request-id")
    stub_fetch(scraper, CoffeeBagScraper::Page.new(status: 200, body: html, location: nil))

    content = scraper.__send__(:page_content, "https://93.184.216.34")

    assert_includes content, '"brand":"Kaffeemacher"'
    assert_includes content, "og:description: Washed Ethiopian coffee with notes of peach"
    assert_not_includes content, "Organization"
    assert_not_includes content, "render()"
  end

  test "fetches over HTTP/2 with curl pinned to the checked address" do
    scraper = CoffeeBagScraper.new(create(:user), "https://shop.example", "request-id")
    calls = []
    original = Open3.method(:capture3)
    Open3.define_singleton_method(:capture3) do |*args|
      calls << args
      File.write(args[args.index("--output") + 1], "<html><body>page</body></html>")
      ["200 ", "", Struct.new(:success?).new(true)]
    end

    page = begin
      scraper.__send__(:fetch, URI("https://shop.example/products/a"), "93.184.216.34")
    ensure
      Open3.define_singleton_method(:capture3, original)
    end

    assert_equal 200, page.status
    assert_equal "<html><body>page</body></html>", page.body
    assert_nil page.location
    args = calls.sole
    assert_includes args, "--http2"
    assert_equal "shop.example:443:93.184.216.34", args[args.index("--resolve") + 1]
    assert_equal "https://shop.example/products/a", args.last
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

  def stub_fetch(scraper, page)
    scraper.define_singleton_method(:public_address) { |_host| "93.184.216.34" }
    scraper.define_singleton_method(:fetch) { |_uri, _address| page }
  end

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
