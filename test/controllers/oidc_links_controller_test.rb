require "test_helper"

class OidcLinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "example.com"
  end

  test "explains the pending email confirmation" do
    get homelab_oidc_link_url

    assert_response :success
    assert_includes response.body, "Check your email"
  end

  test "rejects an invalid token" do
    get confirm_homelab_oidc_link_url(token: "not-a-token")

    assert_redirected_to new_session_url
    assert_equal "That linking link is invalid or has expired.", flash[:alert]
  end

  test "refuses an identity that belongs to another account" do
    other = create(:user, email: "other@example.test")
    create(:identity, user: other, provider: "homelab_oidc", uid: "taken-subject")
    user = create(:user, email: "owner@example.test")
    token = Rails.application.message_verifier(:oidc_link).generate(
      {"user_id" => user.id, "sub" => "taken-subject", "email" => user.email},
      expires_in: 15.minutes
    )

    assert_no_difference "Identity.count" do
      get confirm_homelab_oidc_link_url(token:)
    end

    assert_redirected_to new_session_url
    assert_match(/another account/, flash[:alert])
  end
end
