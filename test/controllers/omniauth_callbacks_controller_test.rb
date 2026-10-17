require "test_helper"

class OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @issuer = "https://auth.example.test"
    @previous_issuer = ENV["OIDC_ISSUER"]
    @previous_admin_group = ENV["OIDC_ADMIN_GROUP"]
    ENV["OIDC_ISSUER"] = @issuer
    ENV.delete("OIDC_ADMIN_GROUP")
    host! "example.com"
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:airtable] = OmniAuth::AuthHash.new(
      provider: "airtable",
      uid: "airtable-uid",
      credentials: {token: "token", refresh_token: "refresh", expires_at: 1.hour.from_now.to_i}
    )
  end

  teardown do
    ENV["OIDC_ISSUER"] = @previous_issuer
    ENV["OIDC_ADMIN_GROUP"] = @previous_admin_group
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:airtable] = nil
  end

  test "requires POST for the OIDC login request" do
    assert_equal [:post], OmniAuth.config.allowed_request_methods
  end

  test "GET is rejected and the sign-in form starts the OIDC flow with POST" do
    previous_oidc_values = %w[OIDC_ISSUER OIDC_CLIENT_ID OIDC_CLIENT_SECRET].to_h { |key| [key, ENV[key]] }
    ENV["OIDC_ISSUER"] = "https://auth.example.test"
    ENV["OIDC_CLIENT_ID"] = "visualizer-test-client"
    ENV["OIDC_CLIENT_SECRET"] = "visualizer-test-secret"

    get "/auth/homelab_oidc"

    assert_response :method_not_allowed
    assert_equal "POST", response.headers["Allow"]

    get new_session_url

    assert_response :success
    assert_select "form[action=?][method=post]", sign_in_with_homelab_oidc_path
    assert_equal "POST", Rails.application.routes.routes.find { |route| route.name == "sign_in_with_homelab_oidc" }.verb
  ensure
    previous_oidc_values&.each { |key, value| ENV[key] = value }
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

  test "rejects a callback issued by a different provider" do
    assert_no_difference ["User.count", "Identity.count", "Session.count"] do
      get homelab_oidc_callback_url, env: oidc_env("wrong-issuer", "new@example.test", true, [], "https://evil.example.test")
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

  test "airtable callback connects premium users" do
    user = create(:user, :premium)
    sign_in(user)

    assert_enqueued_with(job: AirtableUploadAllJob, args: [user]) do
      get "/auth/airtable/callback"
    end

    assert_redirected_to shots_path
    assert_equal 1, user.identities.by_provider(:airtable).count
  end

  test "airtable callback ignores non-premium users" do
    user = create(:user)
    sign_in(user)

    assert_no_enqueued_jobs do
      get "/auth/airtable/callback"
    end

    assert_redirected_to premium_index_path
    assert_empty user.identities
  end

  test "airtable callback requires authentication" do
    assert_no_difference "Identity.count" do
      get "/auth/airtable/callback"
    end

    assert_redirected_to new_session_url
  end

  private

  def oidc_env(subject, email = "user@example.test", email_verified = true, groups = nil, issuer = @issuer)
    raw_info = {"iss" => issuer}
    raw_info["groups"] = groups if groups
    {"omniauth.auth" => {
      "provider" => "homelab_oidc",
      "uid" => subject,
      "info" => {"email" => email, "email_verified" => email_verified},
      "extra" => {"raw_info" => raw_info}
    }}
  end
end
