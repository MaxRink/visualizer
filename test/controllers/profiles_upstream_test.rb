require "test_helper"

class ProfilesUpstreamTest < ActionDispatch::IntegrationTest
  setup do
    host! "example.com"
    @user = create(:user)
    sign_in(@user)
  end

  test "saves mirroring settings and keeps the token when the field is blank" do
    patch profile_url, params: {user: {upstream_push_enabled: "1", upstream_api_token: "secret-token", upstream_base_url: "https://upstream.test"}}

    assert_redirected_to shots_url(format: :html)
    @user.reload
    assert @user.upstream_push_enabled?
    assert_equal "secret-token", @user.upstream_api_token

    patch profile_url, params: {user: {upstream_base_url: "https://other.test"}}

    assert_equal "secret-token", @user.reload.upstream_api_token
    assert_equal "https://other.test", @user.upstream_base_url
  end

  test "never renders the configured token" do
    @user.update!(upstream_push_enabled: true, upstream_api_token: "secret-token")

    get edit_profile_url

    assert_response :success
    assert_not_includes response.body, "secret-token"
    assert_includes response.body, "Token configured"
  end

  test "send test reports success" do
    @user.update!(upstream_base_url: "https://upstream.test", upstream_api_token: "secret-token")
    stub_request(:get, "https://upstream.test/api/me").with(headers: {"Authorization" => "Bearer secret-token"}).to_return(status: 200, body: "{}")

    post test_upstream_push_profile_url

    assert_redirected_to edit_profile_url
    assert_equal "Upstream accepted the token.", flash[:notice]
    assert @user.reload.upstream_push_checked_at.present?
  end

  test "send test reports failure" do
    @user.update!(upstream_base_url: "https://upstream.test", upstream_api_token: "bad-token")
    stub_request(:get, "https://upstream.test/api/me").to_return(status: 401)

    post test_upstream_push_profile_url

    assert_redirected_to edit_profile_url
    assert_match(/rejected/, flash[:alert])
  end

  test "clearing the token disables mirroring" do
    @user.update!(upstream_push_enabled: true, upstream_api_token: "secret-token")

    delete clear_upstream_token_profile_url

    @user.reload
    assert_nil @user.upstream_api_token
    assert_not @user.upstream_push_enabled?
  end
end
