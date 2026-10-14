require "test_helper"

class OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @issuer = "https://auth.example.test"
    @previous_issuer = ENV["OIDC_ISSUER"]
    @previous_admin_group = ENV["OIDC_ADMIN_GROUP"]
    ENV["OIDC_ISSUER"] = @issuer
    ENV.delete("OIDC_ADMIN_GROUP")
  end

  teardown do
    ENV["OIDC_ISSUER"] = @previous_issuer
    ENV["OIDC_ADMIN_GROUP"] = @previous_admin_group
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

  test "maps only the configured OIDC admin group to admin and developer" do
    ENV["OIDC_ADMIN_GROUP"] = "homelab-admins"

    assert_difference ["User.count", "Identity.count", "Session.count"], 1 do
      get homelab_oidc_callback_url, env: oidc_env("admin-subject", "admin@example.test", true, ["homelab-admins"])
    end

    user = User.find_by!(email: "admin@example.test")
    assert user.admin?
    assert user.developer?
  end

  test "restores the prior native roles when the trusted group is removed" do
    ENV["OIDC_ADMIN_GROUP"] = "homelab-admins"
    user = create(:user, admin: false, developer: false)
    identity = create(:identity, user:, provider: "homelab_oidc", uid: "role-subject")

    get homelab_oidc_callback_url, env: oidc_env("role-subject", user.email, true, ["homelab-admins"])
    user.reload
    assert user.admin?
    assert user.developer?

    get homelab_oidc_callback_url, env: oidc_env("role-subject", user.email, true, ["users"])
    user.reload
    identity.reload
    assert_not user.admin?
    assert_not user.developer?
    assert_not identity.oidc_role_managed?
  end

  test "does not remove a native admin role when OIDC management is revoked" do
    ENV["OIDC_ADMIN_GROUP"] = "homelab-admins"
    user = create(:user, admin: true, developer: true)
    create(:identity, user:, provider: "homelab_oidc", uid: "native-admin-subject")

    get homelab_oidc_callback_url, env: oidc_env("native-admin-subject", user.email, true, ["homelab-admins"])
    identity = user.identities.find_by!(provider: "homelab_oidc")
    get homelab_oidc_callback_url, env: oidc_env("native-admin-subject", user.email, true, ["users"])

    user.reload
    identity.reload
    assert user.admin?
    assert user.developer?
    assert_not identity.oidc_role_managed?
  end

  test "does not grant admin when the trusted group is absent" do
    ENV["OIDC_ADMIN_GROUP"] = "homelab-admins"

    get homelab_oidc_callback_url, env: oidc_env("ordinary-subject", "ordinary@example.test", true, ["users"])

    user = User.find_by!(email: "ordinary@example.test")
    assert_not user.admin?
    assert_not user.developer?
  end

  test "does not create a user without a verified email claim" do
    assert_no_difference ["User.count", "Identity.count", "Session.count"] do
      get homelab_oidc_callback_url, env: oidc_env("new-subject", "new@example.test", false)
    end

    assert_redirected_to new_session_url
  end

  test "does not link an unrecognised subject by matching email" do
    user = create(:user, email: "owner@example.test")

    get homelab_oidc_callback_url, env: oidc_env("new-subject", "owner@example.test")

    assert_redirected_to new_session_url
    assert_not user.identities.exists?(provider: "homelab_oidc", uid: "new-subject")
  end

  private

  def oidc_env(subject, email = "user@example.test", email_verified = true, groups = nil)
    raw_info = {"iss" => @issuer}
    raw_info["groups"] = groups if groups
    {"omniauth.auth" => {
      "provider" => "homelab_oidc",
      "uid" => subject,
      "info" => {"email" => email, "email_verified" => email_verified},
      "extra" => {"raw_info" => raw_info}
    }}
  end
end
