# VAPID keys: environment first, credentials as the fallback. Push is disabled
# rather than broken when the keys are absent.
module WebPushConfig
  module_function

  def public_key
    ENV["WEBPUSH_PUBLIC_KEY"].presence || Rails.application.credentials.dig(:webpush, :public_key).presence
  end

  def private_key
    ENV["WEBPUSH_PRIVATE_KEY"].presence || Rails.application.credentials.dig(:webpush, :private_key).presence
  end

  def configured?
    public_key.present? && private_key.present?
  end
end
