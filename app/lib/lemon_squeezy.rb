require "net/http"
require "json"
require "uri"

class LemonSqueezy
  class NotConfigured < StandardError; end

  def self.api_key
    ENV["LEMON_SQUEEZY_API_KEY"].presence || Rails.application.credentials.dig(:lemon_squeezy, :api_key).presence
  end

  def self.webhook_secret
    ENV["LEMON_SQUEEZY_WEBHOOK_SECRET"].presence || Rails.application.credentials.dig(:lemon_squeezy, :webhook_secret).presence
  end

  def self.configured?
    api_key.present?
  end

  def create_checkout(data)
    Client.new("/checkouts", method: :post, data:).make_request
  end

  def get_customer(id)
    Client.new("/customers/#{id}").make_request
  end

  def get_customers(params: {})
    Client.new("/customers", params:).make_request
  end

  def get_subscription(id)
    Client.new("/subscriptions/#{id}").make_request
  end

  def get_subscriptions(params: {})
    Client.new("/subscriptions", params:).make_request
  end

  def all_subscriptions
    Client.new("/subscriptions").paginate
  end

  def all_customers
    Client.new("/customers").paginate
  end
end
