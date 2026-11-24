# Cloudflare Turnstile keys: environment first, credentials as the fallback.
module TurnstileConfig
  module_function

  def site_key
    ENV["TURNSTILE_SITE_KEY"].presence || Rails.application.credentials.dig(:cloudflare, :site_key).presence
  end

  def secret_key
    ENV["TURNSTILE_SECRET_KEY"].presence || Rails.application.credentials.dig(:cloudflare, :secret_key).presence
  end

  def configured?
    site_key.present? && secret_key.present?
  end
end
