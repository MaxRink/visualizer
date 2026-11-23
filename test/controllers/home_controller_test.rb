require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "signed-out landing is the compact self-hosted page" do
    get root_url

    assert_response :success
    assert_includes response.body, Instance::NOTICE
    assert_includes response.body, "Sign in"
    assert_not_includes response.body, "Get started"
    assert_not_includes response.body, "Upgrade to Premium"
  end

  test "signed-in root goes straight to the shots" do
    sign_in(create(:user))

    get root_url

    assert_redirected_to shots_url
  end
end
