require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "example.com"
    @user = create(:user)
    @user.avatar.attach(png_upload)
    @saved_blob = @user.avatar_attachment.blob
    sign_in(@user)
  end

  test "update keeps the saved avatar when a new avatar comes with invalid fields" do
    patch profile_url, params: invalid_params

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_saved_avatar_rendered
  end

  test "update keeps the saved avatar in the Turbo Stream response" do
    patch profile_url, params: invalid_params, headers: {"Accept" => "text/vnd.turbo-stream.html"}

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_saved_avatar_rendered
  end

  test "hides the Airtable connect button when credentials are missing" do
    sign_in(create(:user, :premium))

    get edit_profile_url

    assert_response :success
    assert_not_includes response.body, "Connect Airtable"
  end

  test "shows the Airtable connect button when credentials are configured" do
    sign_in(create(:user, :premium))

    stubbing(User, :airtable_configured?, true) do
      get edit_profile_url
    end

    assert_response :success
    assert_includes response.body, "Connect Airtable"
  end

  test "hides push notifications when VAPID keys are missing" do
    get edit_profile_url

    assert_response :success
    assert_not_includes response.body, "push-notifications"
  end

  test "shows push notifications when VAPID keys are configured" do
    stubbing(User, :web_push_configured?, true) do
      get edit_profile_url
    end

    assert_response :success
    assert_includes response.body, "push-notifications"
  end

  private

  def stubbing(receiver, method_name, value)
    original = receiver.method(method_name)
    receiver.define_singleton_method(method_name) { value }
    yield
  ensure
    receiver.define_singleton_method(method_name, original)
  end

  def invalid_params
    {user: {avatar: png_upload, public: "1", name: "", email_notifications: [""]}}
  end

  def assert_saved_avatar_rendered
    assert_equal @saved_blob, @user.reload.avatar.blob
    assert_includes response.body, @saved_blob.signed_id
  end

  def png_upload
    file = Tempfile.new(["avatar", ".png"], binmode: true)
    file.write("\x89PNG\r\n\x1A\n".b + SecureRandom.random_bytes(16))
    file.rewind
    Rack::Test::UploadedFile.new(file, "image/png", true, original_filename: "avatar.png")
  end
end
