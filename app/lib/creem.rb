class Creem
  class NotConfigured < StandardError; end
  class SignatureVerificationError < StandardError; end
  class UserNotFoundError < StandardError; end

  class APIError < StandardError
    attr_reader :code

    def initialize(message, code)
      @code = code
      super(message)
    end
  end

  BASE_URL = "https://#{Rails.env.local? ? 'test-' : ''}api.creem.io/v1".freeze

  def self.api_key
    ENV["CREEM_API_KEY"].presence || Rails.application.credentials.dig(:creem, :api_key).presence
  end

  def self.webhook_secret
    ENV["CREEM_WEBHOOK_SECRET"].presence || Rails.application.credentials.dig(:creem, :webhook_secret).presence
  end

  def self.product_id
    ENV["CREEM_PRODUCT_ID"].presence || Rails.application.credentials.dig(:creem, :product_id).presence
  end

  def self.product_id_trial
    ENV["CREEM_PRODUCT_ID_TRIAL"].presence || Rails.application.credentials.dig(:creem, :product_id_trial).presence
  end

  def self.configured?
    api_key.present? && product_id.present?
  end

  def create_checkout(data)
    Client.new("/checkouts", method: :post, data:).make_request
  end

  def create_customer_portal(customer_id)
    Client.new("/customers/billing", method: :post, data: {customer_id:}).make_request
  end

  def get_subscription(subscription_id)
    Client.new("/subscriptions", params: {subscription_id:}).make_request
  end

  def all_subscriptions
    Client.new("/subscriptions/search").paginate
  end
end
