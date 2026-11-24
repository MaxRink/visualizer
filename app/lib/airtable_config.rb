# Airtable OAuth credentials: environment first, credentials as the fallback.
# All reads are nil-safe, so a missing section is "not configured", not a 500.
module AirtableConfig
  module_function

  def client_id
    ENV["AIRTABLE_CLIENT_ID"].presence || Rails.application.credentials.dig(:airtable, :client_id).presence
  end

  def client_secret
    ENV["AIRTABLE_CLIENT_SECRET"].presence || Rails.application.credentials.dig(:airtable, :client_secret).presence
  end

  def configured?
    client_id.present? && client_secret.present?
  end
end
