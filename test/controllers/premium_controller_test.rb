require "test_helper"

class PremiumControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "example.com"
  end

  test "index directs JSON requests to the API documentation" do
    get premium_index_url(format: :json)

    assert_response :not_acceptable
    assert_equal "application/json", response.media_type
    assert_equal({"error" => "This is not an API endpoint."}, response.parsed_body)
  end

  test "index renders HTML with wildcard accept" do
    get premium_index_url, headers: {"Accept" => "*/*"}

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_includes response.body, "Everything is included"
  end

  test "billing pages are not found when self-hosted" do
    previous = ENV["VISUALIZER_SELF_HOSTED"]
    ENV["VISUALIZER_SELF_HOSTED"] = "true"

    get premium_index_url

    assert_response :not_found
  ensure
    ENV["VISUALIZER_SELF_HOSTED"] = previous
  end

  test "header hides subscription management when self-hosted" do
    user = create(:user, creem_customer_id: "cust_self_hosted_test")
    sign_in user

    get shots_url
    assert_response :success
    assert_includes response.body, "Manage Subscription"

    previous = ENV["VISUALIZER_SELF_HOSTED"]
    ENV["VISUALIZER_SELF_HOSTED"] = "true"
    get shots_url

    assert_response :success
    assert_not_includes response.body, "Manage Subscription"
    assert_not_includes response.body, "Upgrade to Premium"
  ensure
    ENV["VISUALIZER_SELF_HOSTED"] = previous
  end
end
