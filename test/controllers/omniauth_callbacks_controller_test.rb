require "test_helper"

class OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @issuer = "https://auth.example.test"
    @previous_issuer = ENV["OIDC_ISSUER"]
    ENV["OIDC_ISSUER"] = @issuer
  end

  teardown do
    ENV["OIDC_ISSUER"] = @previous_issuer
  end

  test "requires POST for the OIDC login request" do
    assert_equal [:post], OmniAuth.config.allowed_request_methods
  end

  test "direct GET starts the OmniAuth flow without raising a missing controller error" do
    # OmniAuth middleware owns the request-phase path before Rails dispatches
    # the route-level method guard. The supported browser entry point remains
    # the POST form, while a direct GET safely redirects to the provider.
    get "/auth/homelab_oidc"

    assert_response :moved_permanently
    assert_match %r{^https?://example\.com/}, response.headers["Location"]
  end

  test "signs in an identity matched by issuer and subject" do
    user = create(:user)
    create(:identity, user:, provider: "homelab_oidc", uid: "subject-1")

    get homelab_oidc_callback_url, env: oidc_env("subject-1")

    assert_redirected_to shots_url
    assert_equal user.id, Session.order(:created_at).last.user_id
  end

  test "creates a confirmed user for a new verified identity" do
    assert_difference ["User.count", "Identity.count", "Session.count"], 1 do
      get homelab_oidc_callback_url, env: oidc_env("new-subject", "new@example.test", true)
    end

    user = User.find_by!(email: "new@example.test")
    assert user.confirmed?
    assert_redirected_to shots_url
    assert_equal user.id, Session.order(:created_at).last.user_id
  end

  test "does not create a user without a verified email claim" do
    assert_no_difference ["User.count", "Identity.count", "Session.count"] do
      get homelab_oidc_callback_url, env: oidc_env("new-subject", "new@example.test", false)
    end

    assert_redirected_to new_session_url
  end

  test "rejects a callback issued by a different provider" do
    assert_no_difference ["User.count", "Identity.count", "Session.count"] do
      get homelab_oidc_callback_url, env: oidc_env("wrong-issuer", "new@example.test", true, "https://evil.example.test")
    end

    assert_redirected_to new_session_url
  end

  test "linking an OIDC identity to the signed-in local admin preserves admin access" do
    admin = create(:user, :admin)
    sign_in(admin)

    assert_difference "Identity.count", 1 do
      get homelab_oidc_callback_url, env: oidc_env("admin-subject", admin.email, true)
    end

    assert_redirected_to shots_url
    assert admin.reload.admin?
    assert_equal admin, Identity.find_by!(provider: "homelab_oidc", uid: "admin-subject").user
  end

  test "does not link an unrecognised subject by matching email" do
    user = create(:user, email: "owner@example.test")

    get homelab_oidc_callback_url, env: oidc_env("new-subject", "owner@example.test")

    assert_redirected_to new_session_url
    assert_not user.identities.exists?(provider: "homelab_oidc", uid: "new-subject")
  end

  private

  def oidc_env(subject, email = "user@example.test", email_verified = true, issuer = @issuer)
    {"omniauth.auth" => {
      "provider" => "homelab_oidc",
      "uid" => subject,
      "info" => {"email" => email, "email_verified" => email_verified},
      "extra" => {"raw_info" => {"iss" => issuer}}
    }}
  end
end
