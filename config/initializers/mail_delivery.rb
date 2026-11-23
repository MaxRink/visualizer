# Production falls back to Postmark when SMTP_ADDRESS is unset. Without a
# Postmark API token that transport cannot deliver anything, so fail at boot
# instead of losing confirmation and password-reset mail at runtime.
Rails.application.config.after_initialize do
  next unless Rails.env.production?
  next unless MailDeliveryConfig.misconfigured?

  raise <<~MESSAGE
    No mail transport is configured.
    Set SMTP_ADDRESS (with SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD) or provide
    postmark.api_token in the Rails credentials. Visualizer sends confirmation
    and password-reset mail and cannot start without a working transport.
  MESSAGE
end
