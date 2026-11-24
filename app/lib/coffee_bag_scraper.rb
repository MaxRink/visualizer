require "resolv"

class CoffeeBagScraper
  class NotConfigured < StandardError; end

  BLOCK_PATTERNS = [
    /your access to this site has been limited/i,
    /access from your area has been temporarily limited/i
  ].freeze
  BLOCKED_RESPONSE_CLASSES = [Net::HTTPTooManyRequests].freeze

  attr_reader :user, :url, :request_id

  # Crawlbase is only the fallback for blocked pages; the OpenAI key is what
  # the lookup cannot work without.
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

    response = get_response(uri)
    if response.nil? || is_blocked?(response)
      crawlbase_content(url)
    elsif response.is_a?(Net::HTTPRedirection)
      redirected_url = URI.join(url, response["location"]).to_s
      page_content(redirected_url, limit - 1)
    else
      content = extract_content(response)
      content.size < 100 ? crawlbase_content(url) : content
    end
  end

  def get_response(uri)
    addresses = Resolv.getaddresses(uri.host)
    raise ArgumentError, "URL must resolve to a public IP address" if addresses.empty? || addresses.any? { private_address?(it) }

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", ipaddr: addresses.first, open_timeout: 10) do |http|
      http.get(uri.request_uri)
    end
  rescue Net::OpenTimeout
    nil
  end

  def private_address?(address)
    ip = IPAddr.new(address)
    ip.private? || ip.loopback? || ip.link_local? || ip.multicast? || ip.to_i.zero?
  end

  def crawlbase_content(url)
    token = self.class.crawlbase_token
    raise NotConfigured, "Coffee info lookup is not configured on this instance." if token.blank?

    run_step("retrying") do
      response = SimpleDownloader.new("https://api.crawlbase.com/?token=#{token}&url=#{CGI.escape(url)}").response
      extract_content(response)
    end
  end

  def extract_content(response)
    if response.is_a?(Net::HTTPSuccess)
      doc = Nokogiri::HTML(response.body)
      doc.search("script, style, svg, img").remove
      doc.text.squish
    else
      raise "Failed to fetch page: #{response.code} #{response.message}"
    end
  end

  def is_blocked?(response)
    body = response.body.to_s
    BLOCKED_RESPONSE_CLASSES.any? { |response_class| response.is_a?(response_class) } ||
      BLOCK_PATTERNS.any? { |pattern| body.match?(pattern) }
  end
end
