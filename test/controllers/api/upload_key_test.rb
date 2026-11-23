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

    test "does not create a persisted session or set a session cookie" do
      assert_no_difference "Session.count" do
        get api_me_url, headers: {"Authorization" => "Bearer #{@api_token.token}"}, as: :json
      end

      assert_response :success
      assert_not_includes response.headers["Set-Cookie"].to_s, "session_id="
    end
  end
end
