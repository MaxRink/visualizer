class OmniauthCallbacksController < ApplicationController
  OIDC_LINK_TTL = 15.minutes

  # Airtable is an authenticated premium integration; OIDC must remain public
  # for first-time sign-in and account linking.
  before_action :require_authentication, :check_premium!, only: :airtable
  skip_before_action :reject_unconfirmed_user, only: :homelab_oidc

  def airtable
    oauth = OauthWrapper.new(request.env["omniauth.auth"])
    identity = Identity.find_by(oauth.identifiers)
    if identity
      identity.update!({user_id: Current.user.id}.merge(oauth.identifiers_with_blob_and_token))
    else
      Current.user.identities.create!(oauth.identifiers_with_blob_and_token)
    end
    Airtable::Base.new(Current.user)
    AirtableUploadAllJob.perform_later(Current.user)

    redirect_to shots_path, notice: "Successfully connected to Airtable"
  rescue Airtable::BaseError
    redirect_to shots_path, alert: "Airtable not connected. Visualizer needs access to a base where you're a Creator. Please connect again and pick one."
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

      apply_oidc_admin_role(identity.user, identity, raw_info)
      start_new_session_for(identity.user)
      redirect_to after_authentication_url
    elsif Current.user
      identity = Current.user.identities.create!(provider: "homelab_oidc", uid: subject, blob: auth)
      apply_oidc_admin_role(Current.user, identity, raw_info)
      redirect_to shots_path, notice: "OpenID Connect account linked"
    else
      existing_user = User.find_by(email:)
      if existing_user
        request_oidc_link_confirmation(existing_user, subject, email, raw_info)
      elsif oidc_invited?(raw_info)
        User.transaction do
          user = User.create!(email:, password: SecureRandom.base58(32), confirmed_at: Time.current, oidc_provisioned: true)
          identity = user.identities.create!(provider: "homelab_oidc", uid: subject, blob: auth)
          apply_oidc_admin_role(user, identity, raw_info)
          start_new_session_for(user)
        end
        redirect_to after_authentication_url, notice: "OpenID Connect account created"
      else
        render_not_invited
      end
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

  # Never link on the IdP's email claim alone: when the address already belongs
  # to an account, the owner must confirm a short-lived link sent to that
  # address (a signed-in user links through the session branch above instead).
  def request_oidc_link_confirmation(user, subject, email, raw_info)
    return oidc_failure("Confirm your email address first, then link OpenID Connect.") unless user.confirmed?

    token = Rails.application.message_verifier(:oidc_link).generate(
      {
        "user_id" => user.id,
        "sub" => subject,
        "email" => email,
        "group" => OidcRole.matched_group(raw_info["groups"] || raw_info[:groups])
      },
      expires_in: OIDC_LINK_TTL
    )
    UserMailer.with(user:, token:).oidc_link.deliver_later

    redirect_to homelab_oidc_link_path, notice: "Check #{user.email} for a link to finish connecting OpenID Connect."
  end

  # OIDC_ALLOWED_GROUP, when set, admits new accounts only from that group;
  # unset keeps the previous "any verified identity" behaviour.
  def oidc_invited?(raw_info)
    allowed_group = ENV["OIDC_ALLOWED_GROUP"].to_s.strip
    return true if allowed_group.blank?

    OidcRole.matched_group(raw_info["groups"] || raw_info[:groups], trusted_group: allowed_group).present?
  end

  def render_not_invited
    render "omniauth_callbacks/not_invited", status: :forbidden
  end

  def apply_oidc_admin_role(user, identity, raw_info)
    groups = raw_info["groups"] || raw_info[:groups]
    OidcRole.apply(user, identity, group: OidcRole.matched_group(groups))
  end
end
