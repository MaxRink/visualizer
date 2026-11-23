require "test_helper"

class AppsignalConfigTest < ActiveSupport::TestCase
  test "configured when the push API key comes from the environment" do
    previous = ENV["APPSIGNAL_PUSH_API_KEY"]
    ENV["APPSIGNAL_PUSH_API_KEY"] = "test-key"
    begin
      assert AppsignalConfig.configured?
    ensure
      ENV["APPSIGNAL_PUSH_API_KEY"] = previous
    end
  end

  test "not configured without an environment key or credentials" do
    previous = ENV["APPSIGNAL_PUSH_API_KEY"]
    ENV.delete("APPSIGNAL_PUSH_API_KEY")
    begin
      assert_not AppsignalConfig.configured?
    ensure
      ENV["APPSIGNAL_PUSH_API_KEY"] = previous
    end
  end
end
