require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create(:user, :admin)
    @user = create(:user)
  end

  test "anonymous visitors get a 404" do
    get admin_users_url

    assert_response :not_found
  end

  test "non-admins get a 404" do
    sign_in(@user)

    get admin_users_url

    assert_response :not_found
  end

  test "admins see the user list with instance notice" do
    sign_in(@admin)
    create(:identity, user: @user, provider: "homelab_oidc", uid: "subject")

    get admin_users_url

    assert_response :success
    assert_includes response.body, @user.email
    assert_includes response.body, "OpenID Connect"
    assert_includes response.body, Instance::NOTICE
  end

  test "promotes and demotes a user" do
    sign_in(@admin)

    post promote_admin_user_url(@user)
    assert_redirected_to admin_users_url
    assert @user.reload.admin?

    post demote_admin_user_url(@user)
    assert_redirected_to admin_users_url
    assert_not @user.reload.admin?
  end

  test "disables and enables a user" do
    sign_in(@admin)

    post disable_admin_user_url(@user)
    assert @user.reload.disabled?

    post enable_admin_user_url(@user)
    assert_not @user.reload.disabled?
  end

  test "revokes the upload keys of a user" do
    sign_in(@admin)
    token = create(:api_token, user: @user)

    delete revoke_upload_key_admin_user_url(@user)

    assert_redirected_to admin_users_url
    assert token.reload.revoked?
  end

  test "deletes a user and keeps their shots" do
    sign_in(@admin)
    shot = create(:shot, user: @user)

    assert_difference "User.count", -1 do
      delete admin_user_url(@user)
    end

    assert_redirected_to admin_users_url
    assert Shot.exists?(shot.id)
    assert_nil shot.reload.user_id
  end

  test "refuses to demote the last admin" do
    sign_in(@admin)

    post demote_admin_user_url(@admin)

    assert_redirected_to admin_users_url
    assert_equal "You cannot remove the last admin.", flash[:alert]
    assert @admin.reload.admin?
  end

  test "refuses to disable the last admin" do
    sign_in(@admin)

    post disable_admin_user_url(@admin)

    assert_redirected_to admin_users_url
    assert @admin.reload.admin?
    assert_nil @admin.disabled_at
  end

  test "refuses to delete the last admin" do
    sign_in(@admin)

    assert_no_difference "User.count" do
      delete admin_user_url(@admin)
    end

    assert_redirected_to admin_users_url
    assert @admin.reload.persisted?
  end

  test "allows demoting an admin when another admin remains" do
    other = create(:user, :admin)
    sign_in(@admin)

    post demote_admin_user_url(other)

    assert_redirected_to admin_users_url
    assert_not other.reload.admin?
  end
end
