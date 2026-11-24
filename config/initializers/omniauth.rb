Rails.application.config.middleware.use OmniAuth::Builder do
  # Test mode needs the strategy registered even without real client keys.
  if AirtableConfig.configured? || Rails.env.test?
    provider(
      :airtable,
      AirtableConfig.client_id,
      AirtableConfig.client_secret,
      scope: "data.records:read data.records:write schema.bases:read schema.bases:write webhook:manage"
    )
  end

  if ENV["OIDC_ISSUER"].present? && ENV["OIDC_CLIENT_ID"].present? && ENV["OIDC_CLIENT_SECRET"].present?
    provider(
      :openid_connect,
      name: :homelab_oidc,
      scope: %i[openid profile email groups],
      response_type: :code,
      pkce: true,
      issuer: ENV.fetch("OIDC_ISSUER"),
      discovery: true,
      client_options: {
        identifier: ENV.fetch("OIDC_CLIENT_ID"),
        secret: ENV.fetch("OIDC_CLIENT_SECRET"),
        redirect_uri: ENV.fetch("OIDC_REDIRECT_URI", "#{ENV.fetch("APP_PROTOCOL", "https")}://#{ENV.fetch("APP_HOST", "localhost")}/auth/homelab_oidc/callback")
      }
    )
  end
end
