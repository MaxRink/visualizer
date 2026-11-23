require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  test "show returns ok when database is reachable" do
    get db_health_check_url

    assert_response :ok
  end

  test "show returns service unavailable when database is unreachable" do
    connection = ActiveRecord::Base.connection
    connection.define_singleton_method(:select_value) { |*| raise ActiveRecord::ConnectionNotEstablished }

    get db_health_check_url

    assert_response :service_unavailable
  ensure
    connection.singleton_class.remove_method(:select_value)
  end

  test "reports build, fork and database status without secrets" do
    get health_url

    assert_response :success
    body = response.parsed_body
    assert_equal "ok", body["status"]
    assert_equal true, body["fork"]
    assert_equal true, body["database"]
    assert body.key?("version")
    assert body.key?("commit")
    assert_not body.key?("secret")
  end

  test "reports the self-hosted flag from the deployment" do
    previous = ENV["VISUALIZER_SELF_HOSTED"]
    ENV["VISUALIZER_SELF_HOSTED"] = "true"
    begin
      get health_url
    ensure
      ENV["VISUALIZER_SELF_HOSTED"] = previous
    end

    assert_equal true, response.parsed_body["self_hosted"]
  end
end
