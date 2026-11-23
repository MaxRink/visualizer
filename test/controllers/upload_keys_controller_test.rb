require "test_helper"

class UploadKeysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    sign_in @user
  end

  test "creates a named key and shows it on the profile page" do
    assert_difference -> { @user.api_tokens.count }, 1 do
      post profile_upload_keys_url, params: {name: "Beanconqueror"}
    end

    assert_redirected_to edit_profile_url
    key = @user.api_tokens.order(:created_at).last
    assert_equal "Beanconqueror", key.name

    follow_redirect!
    assert_response :success
    assert_includes response.body, "Beanconqueror"
    assert_includes response.body, key.masked_token
    assert_includes response.body, key.token
  end

  test "keeps several keys active at the same time" do
    post profile_upload_keys_url, params: {name: "Laptop"}
    post profile_upload_keys_url, params: {name: "Phone"}

    assert_equal %w[Laptop Phone], @user.api_tokens.active.order(:created_at).pluck(:name)

    get edit_profile_url
    assert_response :success
    assert_includes response.body, "Laptop"
    assert_includes response.body, "Phone"
  end

  test "falls back to a default name" do
    post profile_upload_keys_url, params: {}

    assert_equal "Upload key", @user.api_tokens.order(:created_at).last.name
  end

  test "revokes only the selected key" do
    post profile_upload_keys_url, params: {name: "Laptop"}
    post profile_upload_keys_url, params: {name: "Phone"}
    laptop, phone = @user.api_tokens.active.order(:created_at).to_a

    delete profile_upload_key_url(laptop)

    assert_redirected_to edit_profile_url
    assert laptop.reload.revoked?
    assert_not phone.reload.revoked?
  end

  test "does not revoke another user's key" do
    other = create(:api_token)

    delete profile_upload_key_url(other)

    assert_response :not_found
    assert_not other.reload.revoked?
  end
end
