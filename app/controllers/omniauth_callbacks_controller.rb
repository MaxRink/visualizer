class OmniauthCallbacksController < ApplicationController
  skip_before_action :reject_unconfirmed_user, only: :homelab_oidc

  def airtable
    oauth = OauthWrapper.new(request.env["omniauth.auth"])
    identity = Identity.find_by(oauth.identifiers)
    if identity
      identity.update!({user_id: Current.user.id}.merge(oauth.identifiers_with_blob_and_token))
    else
      Current.user.identities.create!(oauth.identifiers_with_blob_and_token)
    end
    AirtableUploadAllJob.perform_later(Current.user)

    redirect_to shots_path, notice: "Successfully connected to Airtable"
  end

  def homelab_oidc
    auth = request.env.fetch("omniauth.auth")
    raw_info = auth.dig("extra", "raw_info") || {}
    issuer = raw_info["iss"].to_s
    configured_issuer = ENV.fetch("OIDC_ISSUER", "").chomp("/")
    subject = auth.dig("uid").to_s
    return oidc_failure("The identity provider did not return a valid issuer or subject.") if issuer.blank? || subject.blank? || issuer.chomp("/") != configured_issuer

    email = auth.dig("info", "email").to_s.strip.downcase
    email_verified = auth.dig("info", "email_verified")
    email_verified = raw_info["email_verified"] if email_verified.nil?
    return oidc_failure("The identity provider did not return a verified email address.") if email.blank? || !ActiveModel::Type::Boolean.new.cast(email_verified)

    identity = Identity.find_by(provider: "homelab_oidc", uid: subject)
    if identity
      return oidc_failure("That OpenID Connect identity belongs to another account.") if Current.user && identity.user_id != Current.user.id

      start_new_session_for(identity.user)
      redirect_to after_authentication_url
    elsif Current.user
      Current.user.identities.create!(provider: "homelab_oidc", uid: subject, blob: auth)
      redirect_to shots_path, notice: "OpenID Connect account linked"
    elsif User.exists?(email:)
      oidc_failure("Sign in with the local account once before linking OpenID Connect.")
    else
      User.transaction do
        user = User.create!(email:, password: SecureRandom.base58(32), confirmed_at: Time.current)
        user.identities.create!(provider: "homelab_oidc", uid: subject, blob: auth)
        start_new_session_for(user)
      end
      redirect_to after_authentication_url, notice: "OpenID Connect account created"
    end
  rescue ActiveRecord::RecordNotUnique
    oidc_failure("That OpenID Connect identity is already linked to another account.")
  end

  def homelab_oidc_method_not_allowed
    response.set_header("Allow", "POST")
    render plain: "", status: :method_not_allowed, content_type: "text/plain"
  end

  private

  def oidc_failure(message)
    redirect_to new_session_url, alert: message
  end
end
