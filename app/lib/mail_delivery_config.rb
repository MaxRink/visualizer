# Decides whether the configured Action Mailer transport can actually deliver.
# Production refuses to boot without a usable transport, because confirmation
# and password-reset mail silently fail otherwise.
module MailDeliveryConfig
  module_function

  def postmark_token(action_mailer = Rails.application.config.action_mailer)
    settings = action_mailer.postmark_settings || {}
    settings[:api_token] || settings["api_token"]
  end

  def misconfigured?(action_mailer = Rails.application.config.action_mailer)
    return false unless action_mailer.delivery_method == :postmark

    postmark_token(action_mailer).blank?
  end
end
