require "test_helper"

class UploadKeysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    sign_in @user
  end

  test "generates a key and shows it on the profile page" do
    assert_difference -> { @user.api_tokens.count }, 1 do
      post profile_upload_key_url
    end

    assert_redirected_to edit_profile_url

    follow_redirect!
    assert_response :success

    key = @user.api_tokens.active.last
    assert_includes response.body, key.masked_token
    assert_includes response.body, key.token
  end

  test "profile page offers creating a key when none exists" do
    get edit_profile_url

    assert_response :success
    assert_includes response.body, "Create upload key"
  end

  test "regenerating revokes the previous key" do
    post profile_upload_key_url
    previous = @user.api_tokens.active.last

    post profile_upload_key_url

    assert previous.reload.revoked?
    assert_equal 1, @user.api_tokens.active.count
    assert_not_equal previous.token, @user.api_tokens.active.last.token
  end

  test "revoking removes the active key" do
    post profile_upload_key_url
    delete profile_upload_key_url

    assert_redirected_to edit_profile_url
    assert_equal 0, @user.api_tokens.active.count
  end
end
