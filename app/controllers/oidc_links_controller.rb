# Confirmation step for linking OpenID Connect to an existing local account.
# The callback emails a short-lived signed link to the account address; this
# controller finishes the link once the owner proves control of that inbox.
class OidcLinksController < ApplicationController
  rate_limit to: 10, within: 15.minutes, name: "oidc-link-confirm", only: :confirm, with: -> { redirect_to new_session_url, alert: "Try again later." }

  def show; end

  def confirm
    payload = Rails.application.message_verifier(:oidc_link).verified(params[:token].to_s)
    return oidc_link_failure if payload.blank?

    user = User.find_by(id: payload["user_id"])
    return oidc_link_failure if user.blank?
    return oidc_link_failure if payload["sub"].to_s.blank?
    return oidc_link_failure("Confirm your email address first, then link OpenID Connect.") unless user.confirmed?
    return oidc_link_failure("That account has been disabled.") if user.disabled?

    identity = Identity.find_by(provider: "homelab_oidc", uid: payload["sub"].to_s)
    return oidc_link_failure("That OpenID Connect identity belongs to another account.") if identity && identity.user_id != user.id

    identity ||= user.identities.create!(
      provider: "homelab_oidc",
      uid: payload["sub"].to_s,
      blob: {"info" => {"email" => payload["email"].to_s}}
    )
    OidcRole.apply(user, identity, group: payload["group"].presence)
    start_new_session_for(user)

    redirect_to after_authentication_url, notice: "OpenID Connect account linked."
  rescue ActiveRecord::RecordNotUnique
    oidc_link_failure("That OpenID Connect identity is already linked to another account.")
  end

  private

  def oidc_link_failure(message = "That linking link is invalid or has expired.")
    redirect_to new_session_url, alert: message
  end
end
