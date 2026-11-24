require "test_helper"

class CoffeeBagScraperFormTest < ActionDispatch::IntegrationTest
  setup do
    host! "example.com"
    sign_in(create(:user, :with_coffee_management))
  end

  test "hides the fetch button when the scraper is not configured" do
    without_openai_key do
      get new_coffee_bag_url
    end

    assert_response :success
    assert_not_includes response.body, "Get info"
  end

  test "shows the fetch button when the scraper is configured" do
    previous = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = "test-key"
    begin
      get new_coffee_bag_url
    ensure
      ENV["OPENAI_API_KEY"] = previous
    end

    assert_response :success
    assert_includes response.body, "Get info"
  end

  private

  def without_openai_key
    previous = ENV["OPENAI_API_KEY"]
    ENV.delete("OPENAI_API_KEY")
    yield
  ensure
    ENV["OPENAI_API_KEY"] = previous
  end
end
