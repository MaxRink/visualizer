require "test_helper"

class WebhookControllerTest < ActionDispatch::IntegrationTest
  test "billing webhooks are not found when self-hosted" do
    previous = ENV["VISUALIZER_SELF_HOSTED"]
    ENV["VISUALIZER_SELF_HOSTED"] = "true"

    post lemon_squeezy_url, params: {}, as: :json
    assert_response :not_found

    post creem_url, params: {}, as: :json
    assert_response :not_found
  ensure
    ENV["VISUALIZER_SELF_HOSTED"] = previous
  end
end
