ENV["RAILS_ENV"] ||= "test"
ENV["VISUALIZER_INFERENCE_BASE_URL"] = "http://10.255.255.254:30681/v1/chat/completions"
ENV["VISUALIZER_INFERENCE_MODEL"] = "coffee-bag-vision"
ENV["VISUALIZER_INFERENCE_API_KEY"] = "test-only-visualizer-key"
require_relative "../config/environment"

require "rails/test_help"
require "webmock/minitest"

ActiveModel::SecurePassword.min_cost = true

module ActiveSupport
  class TestCase
    include ActiveJob::TestHelper
    include FactoryBot::Syntax::Methods

    parallelize(workers: :number_of_processors)

    setup do
      Rails.cache.clear
      WebMock.disable_net_connect!
    end

    teardown { WebMock.reset! }
  end
end

class ActionDispatch::IntegrationTest
  def sign_in(user)
    post session_url, params: {email: user.email, password: "password"}
  end
end

module SystemOneTestSupport
  ENDPOINT = "http://10.255.255.254:30681/v1/chat/completions"

  def stub_system_one(answers)
    content = {answers:}.to_json
    stub_request(:post, ENDPOINT).with do |request|
      request.headers["Authorization"] == "Bearer test-only-visualizer-key" &&
        request.headers["Content-Type"] == "application/json"
    end.to_return(status: 200, body: {choices: [{message: {content:}}]}.to_json)
  end
end

ActiveSupport::TestCase.include(SystemOneTestSupport)
ActionDispatch::IntegrationTest.include(SystemOneTestSupport)
