require "open3"
require "resolv"

class CoffeeBagScraper
  class NotConfigured < StandardError; end
  class Unavailable < StandardError; end

  Page = Data.define(:status, :body, :location)

  BLOCK_PATTERNS = [
    /your access to this site has been limited/i,
    /access from your area has been temporarily limited/i
  ].freeze
  BLOCKED_STATUSES = [403, 429].freeze
  MIN_CONTENT_SIZE = 100
  MAX_CONTENT_SIZE = 20_000
  MAX_PAGE_BYTES = 5 * 1024 * 1024
  FETCH_TIMEOUT = 20
  STRUCTURED_META = "meta[property^='og:'], meta[property^='product:'], meta[name='description']".freeze

  attr_reader :user, :url, :request_id

  # Crawlbase is an optional fallback for blocked pages; the OpenAI key is
  # what the lookup cannot work without.
  def self.crawlbase_token
    ENV["CRAWLBASE_TOKEN"].presence || Rails.application.credentials.dig(:crawlbase, :token).presence
  end

  def self.configured?
    OpenAi.configured?
  end

  def initialize(user, url, request_id)
    @user = user
    @url = url
    @request_id = request_id
  end

  def scrape
    raise NotConfigured, "Coffee info lookup is not configured on this instance." unless self.class.configured?

    run_step("fetching") { page_content(url) }
      .then { |content| run_step("extracting") { OpenAi.new.message(content) } }
      .then { |response| run_step("finalizing") { self.class.parse_bag(response) } }
  end

  # The model has returned plain text instead of a JSON object before; a
  # non-object payload is a handled failure, not a crash in the job.
  def self.parse_bag(response)
    parsed = JSON.parse(response)
    raise ArgumentError, "The model did not return a coffee bag object" unless parsed.is_a?(Hash)

    parsed.compact_blank
  end

  private

  def run_step(status)
    CoffeeBagScraperChannel.broadcast_to(user, {request_id:, status:})
    yield
  end

  def page_content(url, limit = 5)
    raise ArgumentError, "Too many HTTP redirects" if limit.zero?

    uri = URI.parse(url)
    raise ArgumentError, "URL must be an HTTP or HTTPS URL" unless uri.is_a?(URI::HTTP) && uri.host.present?

    page = fetch(uri, public_address(uri.host))
    if page&.status&.between?(300, 399) && page.location.present?
      page_content(URI.join(url, page.location).to_s, limit - 1)
    else
      usable_content(page) || crawlbase_content(url, page)
    end
  end

  def public_address(host)
    addresses = Resolv.getaddresses(host)
    raise Unavailable, "The coffee page's address could not be resolved." if addresses.empty?
    raise ArgumentError, "URL must resolve to a public IP address" if addresses.any? { private_address?(it) }

    addresses.find { IPAddr.new(it).ipv4? } || addresses.first
  end

  def private_address?(address)
    ip = IPAddr.new(address)
    ip.private? || ip.loopback? || ip.link_local? || ip.multicast? || ip.to_i.zero?
  end

  # curl instead of Net::HTTP: shops behind Shopify's bot protection answer
  # every HTTP/1.1 request with 429, and Net::HTTP cannot speak HTTP/2. The
  # connection is pinned to the address checked above (no DNS rebinding) and
  # redirects are followed by page_content, so each hop is checked again.
  def fetch(uri, address)
    pinned = address.include?(":") ? "[#{address}]" : address
    Tempfile.create("coffee-bag-page") do |file|
      stdout, _stderr, status = Open3.capture3(
        "curl", "--silent", "--http2", "--compressed", "--proto", "=http,https",
        "--connect-timeout", "10", "--max-time", FETCH_TIMEOUT.to_s, "--max-filesize", MAX_PAGE_BYTES.to_s,
        "--resolve", "#{uri.host}:#{uri.port}:#{pinned}", "--output", file.path,
        "--write-out", "%{http_code} %{redirect_url}", uri.to_s
      )
      next unless status.success?

      code, location = stdout.split(" ", 2)
      Page.new(status: code.to_i, body: File.binread(file.path), location: location.to_s.strip.presence)
    end
  end

  def usable_content(page)
    return if page.nil? || blocked?(page)
    raise Unavailable, "Failed to fetch the page (HTTP #{page.status})." unless page.status.between?(200, 299)

    content = extract_content(page.body)
    content if content.size >= MIN_CONTENT_SIZE
  end

  def crawlbase_content(url, page)
    token = self.class.crawlbase_token
    raise Unavailable, unavailable_message(page) if token.blank?

    run_step("retrying") do
      response = SimpleDownloader.new("https://api.crawlbase.com/?token=#{token}&url=#{CGI.escape(url)}").response
      raise Unavailable, "Failed to fetch the page (HTTP #{response.code})." unless response.is_a?(Net::HTTPSuccess)

      extract_content(response.body)
    end
  end

  def unavailable_message(page)
    if page.nil?
      "The coffee page did not respond. Try again later or enter the details manually."
    elsif blocked?(page)
      "The roaster's website blocked the lookup (HTTP #{page.status}). Enter the details manually."
    else
      "The page has no readable coffee details. Enter the details manually."
    end
  end

  # Product pages that render in JavaScript still carry JSON-LD and Open Graph
  # data, so those go first; the visible text follows.
  def extract_content(body)
    doc = Nokogiri::HTML(body)
    structured = doc.css("script[type='application/ld+json']").map { it.text.squish }.select { it.include?("Product") }
    meta = doc.css(STRUCTURED_META).filter_map { "#{it["property"] || it["name"]}: #{it["content"].squish}" if it["content"].present? }
    doc.search("script, style, svg, img").remove
    [*structured, *meta, doc.text.squish].compact_blank.join("\n").truncate(MAX_CONTENT_SIZE)
  end

  def blocked?(page)
    BLOCKED_STATUSES.include?(page.status) || BLOCK_PATTERNS.any? { page.body.to_s.match?(it) }
  end
end
