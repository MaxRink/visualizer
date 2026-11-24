class WebhookController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :reject_self_hosted

  def lemon_squeezy
    LemonSqueezyWebhookHandler.new(request).handle
    head :ok
  rescue LemonSqueezy::NotConfigured
    head :not_found
  rescue JSON::ParserError, LemonSqueezy::SignatureVerificationError
    head :bad_request
  end

  def creem
    CreemWebhookHandler.new(request).handle
    head :ok
  rescue Creem::NotConfigured
    head :not_found
  rescue JSON::ParserError, Creem::SignatureVerificationError, Creem::UserNotFoundError => e
    Appsignal.report_error(e) { Appsignal.add_tags(webhook_id: params["id"]) }
    head :bad_request
  end

  private

  # The routes are not drawn on self-hosted installs; this also covers a custom
  # route set and keeps the endpoints unguessable.
  def reject_self_hosted
    head :not_found if User.self_hosted?
  end
end
