require "test_helper"

class MailDeliveryConfigTest < ActiveSupport::TestCase
  Config = Struct.new(:delivery_method, :postmark_settings)

  test "flags postmark without an api token" do
    assert MailDeliveryConfig.misconfigured?(Config.new(:postmark, {}))
    assert MailDeliveryConfig.misconfigured?(Config.new(:postmark, nil))
  end

  test "accepts postmark with an api token" do
    assert_not MailDeliveryConfig.misconfigured?(Config.new(:postmark, {api_token: "token"}))
    assert_not MailDeliveryConfig.misconfigured?(Config.new(:postmark, {"api_token" => "token"}))
  end

  test "ignores transports that do not need a token" do
    assert_not MailDeliveryConfig.misconfigured?(Config.new(:smtp, {}))
  end
end
