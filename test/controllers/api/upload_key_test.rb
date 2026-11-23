require "test_helper"

module Api
  class UploadKeyTest < ActionDispatch::IntegrationTest
    setup do
      @previous_self_hosted = ENV["VISUALIZER_SELF_HOSTED"]
      @previous_oidc_only = ENV["OIDC_ONLY"]
      ENV["VISUALIZER_SELF_HOSTED"] = "true"
      ENV["OIDC_ONLY"] = "true"

      # Mirrors the just-in-time provisioning in OmniauthCallbacksController:
      # the user is confirmed, has a random unusable password, and has no 2FA.
      @user = create(:user, password: SecureRandom.base58(32))
      @api_token = create(:api_token, user: @user)
    end

    teardown do
      ENV["VISUALIZER_SELF_HOSTED"] = @previous_self_hosted
      ENV["OIDC_ONLY"] = @previous_oidc_only
    end

    test "uploads a shot with a bearer upload key for a user without a local password" do
      file = JSON.parse(Rails.root.join("test/files/beanconqueror.json").read)

      assert_difference "Shot.count", 1 do
        post upload_api_shots_url, headers: {"Authorization" => "Bearer #{@api_token.token}"}, params: file, as: :json
      end

      assert_response :success
      assert_equal @user.id, Shot.find(response.parsed_body["id"]).user_id
      assert @api_token.reload.last_used_at.present?
    end

    test "accepts the upload key in the X-Upload-Key header" do
      file = JSON.parse(Rails.root.join("test/files/beanconqueror.json").read)

      assert_difference "Shot.count", 1 do
        post upload_api_shots_url, headers: {"X-Upload-Key" => @api_token.token}, params: file, as: :json
      end

      assert_response :success
    end

    test "links a coffee bag to the user's own shot" do
      shot = create(:shot, user: @user)
      bag = create(:coffee_bag, roaster: create(:roaster, user: @user))

      patch api_shot_url(shot), headers: {"Authorization" => "Bearer #{@api_token.token}"}, params: {shot: {coffee_bag_id: bag.id}}, as: :json

      assert_response :success
      assert_equal bag.id, shot.reload.coffee_bag_id
    end

    test "rejects a revoked upload key" do
      @api_token.revoke!
      file = JSON.parse(Rails.root.join("test/files/beanconqueror.json").read)

      assert_no_difference "Shot.count" do
        post upload_api_shots_url, headers: {"Authorization" => "Bearer #{@api_token.token}"}, params: file, as: :json
      end

      assert_response :unauthorized
    end

    test "rejects an unknown upload key" do
      assert_no_difference "Shot.count" do
        post upload_api_shots_url, headers: {"Authorization" => "Bearer #{ApiToken::PREFIX}unknown"}, params: {}, as: :json
      end

      assert_response :unauthorized
    end

    test "rejects requests without credentials" do
      post upload_api_shots_url, params: {}, as: :json

      assert_response :unauthorized
    end

    test "cannot change another user's shot" do
      other_user = create(:user)
      shot = create(:shot, user: other_user)
      bag = create(:coffee_bag, roaster: create(:roaster, user: other_user))

      patch api_shot_url(shot), headers: {"Authorization" => "Bearer #{@api_token.token}"}, params: {shot: {coffee_bag_id: bag.id}}, as: :json

      assert_response :forbidden
      assert_nil shot.reload.coffee_bag_id
    end

    test "records the key that uploaded a shot" do
      other = create(:api_token, user: @user, name: "Other")
      file = JSON.parse(Rails.root.join("test/files/beanconqueror.json").read)

      post upload_api_shots_url, headers: {"Authorization" => "Bearer #{other.token}"}, params: file, as: :json

      assert_response :success
      assert_equal other, Shot.find(response.parsed_body["id"]).api_token
    end

    test "records the key when a bag link comes through the API" do
      shot = create(:shot, user: @user)
      bag = create(:coffee_bag, roaster: create(:roaster, user: @user))

      patch api_shot_url(shot), headers: {"Authorization" => "Bearer #{@api_token.token}"}, params: {shot: {coffee_bag_id: bag.id}}, as: :json

      assert_equal @api_token, shot.reload.api_token
    end

    test "does not attribute a plain metadata update" do
      shot = create(:shot, user: @user)

      patch api_shot_url(shot), headers: {"Authorization" => "Bearer #{@api_token.token}"}, params: {shot: {barista: "Sam"}}, as: :json

      assert_nil shot.reload.api_token_id
    end

    test "deleting a key nullifies the attribution but keeps the shot" do
      shot = create(:shot, user: @user, api_token: @api_token)

      @api_token.destroy!

      assert_nil shot.reload.api_token_id
      assert Shot.exists?(shot.id)
    end

    test "a browser upload has no key attribution" do
      browser_user = create(:user)
      sign_in(browser_user)

      post shots_url, params: {files: [fixture_file_upload(Rails.root.join("test/files/beanconqueror.json"), "application/json")]}

      assert_response :redirect
      shot = Shot.order(:created_at).last
      assert_equal browser_user, shot.user
      assert_nil shot.api_token_id
    end

    test "basic auth with an upload key ignores a bogus username" do
      get api_me_url, headers: basic_headers("not-an-email", @api_token.token), as: :json

      assert_response :success
      assert_equal @user.id, response.parsed_body["id"]
    end

    test "basic auth with an upload key and an empty username" do
      get api_me_url, headers: basic_headers("", @api_token.token), as: :json

      assert_response :success
      assert_equal @user.id, response.parsed_body["id"]
    end

    test "basic auth with an unknown upload key is unauthorized" do
      get api_me_url, headers: basic_headers("whoever", "#{ApiToken::PREFIX}unknown"), as: :json

      assert_response :unauthorized
    end

    test "basic auth with a revoked upload key is unauthorized" do
      @api_token.revoke!

      get api_me_url, headers: basic_headers("whoever", @api_token.token), as: :json

      assert_response :unauthorized
    end

    test "basic auth with a real password still works" do
      user = create(:user)

      get api_me_url, headers: basic_headers(user.email, "password"), as: :json

      assert_response :success
      assert_equal user.id, response.parsed_body["id"]
    end

    test "basic auth with an upload key records attribution" do
      file = JSON.parse(Rails.root.join("test/files/beanconqueror.json").read)

      post upload_api_shots_url, headers: basic_headers("anything", @api_token.token), params: file, as: :json

      assert_response :success
      assert_equal @api_token, Shot.find(response.parsed_body["id"]).api_token
      assert @api_token.reload.last_used_at.present?
    end

    test "does not create a persisted session or set a session cookie" do
      assert_no_difference "Session.count" do
        get api_me_url, headers: {"Authorization" => "Bearer #{@api_token.token}"}, as: :json
      end

      assert_response :success
      assert_not_includes response.headers["Set-Cookie"].to_s, "session_id="
    end

    private

    def basic_headers(username, password)
      {"HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(username, password)}
    end
  end
end
