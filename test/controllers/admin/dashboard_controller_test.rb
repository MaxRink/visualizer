require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "shows instance counts and storage" do
    admin = create(:user, :admin)
    create(:shot, user: admin)
    sign_in(admin)

    get admin_root_url

    assert_response :success
    assert_includes response.body, "Active Storage"
    assert_includes response.body, "Oldest shot"
    assert_includes response.body, "Users"
  end

  test "non-admins get a 404" do
    sign_in(create(:user))

    get admin_root_url

    assert_response :not_found
  end
end
