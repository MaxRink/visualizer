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

  test "hides the OpenID Connect section when the provider is not configured" do
    get edit_profile_url

    assert_response :success
    assert_select "form[action=?]", sign_in_with_homelab_oidc_path, count: 0
    assert_select "form[action=?]", disconnect_oidc_profile_path, count: 0
  end

  test "offers linking when no OpenID Connect identity is linked" do
    with_oidc_configured do
      get edit_profile_url
    end

    assert_response :success
    assert_includes response.body, "Link OpenID Connect"
    assert_select "form[action=?]", sign_in_with_homelab_oidc_path
  end

  test "shows the linked identity with an unlink action" do
    create(:identity, user: @user, provider: "homelab_oidc", uid: "subject-1",
      blob: {"info" => {"email" => "linked@example.test"}})

    with_oidc_configured do
      get edit_profile_url
    end

    assert_response :success
    assert_includes response.body, "linked@example.test"
    assert_select "form[action=?]", disconnect_oidc_profile_path
  end

  test "refuses to unlink the only way to sign in" do
    user = create(:user, oidc_provisioned: true)
    identity = create(:identity, user:, provider: "homelab_oidc", uid: "subject-1")
    sign_in(user)

    delete disconnect_oidc_profile_url

    assert_redirected_to edit_profile_url
    assert_match(/passkey/i, flash[:alert])
    assert Identity.exists?(identity.id)
  end

  test "unlinks OpenID Connect when a passkey can still sign in" do
    user = create(:user, oidc_provisioned: true)
    identity = create(:identity, user:, provider: "homelab_oidc", uid: "subject-1")
    create(:webauthn_credential, user:)
    sign_in(user)

    delete disconnect_oidc_profile_url

    assert_redirected_to edit_profile_url
    assert_not Identity.exists?(identity.id)

    get shots_url
    assert_response :success
  end

  private

  def with_oidc_configured
    keys = %w[OIDC_ISSUER OIDC_CLIENT_ID OIDC_CLIENT_SECRET]
    previous = keys.index_with { |key| ENV[key] }
    ENV["OIDC_ISSUER"] = "https://auth.example.test"
    ENV["OIDC_CLIENT_ID"] = "visualizer-test-client"
    ENV["OIDC_CLIENT_SECRET"] = "visualizer-test-secret"
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end

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
