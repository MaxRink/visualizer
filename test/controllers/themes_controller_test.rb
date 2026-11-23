require "test_helper"

class ThemesControllerTest < ActionDispatch::IntegrationTest
  test "persists an explicit skin for signed-in users" do
    user = create(:user)
    sign_in(user)

    patch theme_url, params: {skin: "dark"}, as: :json

    assert_response :success
    assert_equal "Dark", user.reload.skin
  end

  test "rejects unknown skins" do
    sign_in(create(:user))

    patch theme_url, params: {skin: "neon"}, as: :json

    assert_response :unprocessable_content
  end

  test "renders the theme toggle and the server-side skin" do
    get root_url

    assert_select "button[data-controller='theme']"
    assert_select "html[data-skin='system']"
  end

  test "renders the stored skin without waiting for JavaScript" do
    sign_in(create(:user, skin: "Dark"))

    get shots_url

    assert_select "html[data-skin='dark']"
  end
end
