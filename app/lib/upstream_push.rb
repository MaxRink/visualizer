# Pushes one shot to the user's upstream Visualizer instance. The payload is
# the format this app's own upload endpoint accepts (ShotUploadSerializer), so
# it is parsed by the upstream exactly like a normal file upload.
class UpstreamPush
  class RetryableError < StandardError; end
  class PermanentError < StandardError; end

  TIMEOUT = 10

  def initialize(shot)
    @shot = shot
    @user = shot.user
  end

  def call
    raise PermanentError, "mirroring is not configured" unless @user&.upstream_push_enabled? && @user.upstream_api_token.present?

    response = post(upload_uri, ShotUploadSerializer.new(@shot).to_json)

    case response
    when Net::HTTPSuccess
      JSON.parse(response.body).slice("id")
    when Net::HTTPServerError, Net::HTTPRequestTimeout
      raise RetryableError, "upstream answered HTTP #{response.code}"
    else
      raise PermanentError, "upstream answered HTTP #{response.code}"
    end
  rescue Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError => e
    raise RetryableError, e.class.name
  rescue ArgumentError, URI::InvalidURIError => e
    raise PermanentError, e.message
  end

  # Lightweight authenticated check used by the profile's "Send test" action.
  def self.test(user)
    uri = URI.join(base_url(user), "/api/me")
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{user.upstream_api_token}"
    request["Accept"] = "application/json"
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: TIMEOUT, read_timeout: TIMEOUT) { |http| http.request(request) }
    response.is_a?(Net::HTTPSuccess) ? true : "HTTP #{response.code}"
  rescue StandardError => e
    e.class.name
  end

  def self.base_url(user)
    base = user.upstream_base_url.presence || "https://visualizer.coffee"
    base.end_with?("/") ? base : "#{base}/"
  end

  private

  def upload_uri
    URI.join(self.class.base_url(@user), "/api/shots/upload")
  end

  def post(uri, body)
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@user.upstream_api_token}"
    request["Accept"] = "application/json"
    request["Content-Type"] = "application/json"
    request.body = body

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: TIMEOUT, read_timeout: TIMEOUT) { |http| http.request(request) }
  end
end
