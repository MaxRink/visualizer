require "test_helper"

class MetricsControllerTest < ActionDispatch::IntegrationTest
  test "exports bounded HTTP metrics without request content" do
    get "/metrics"

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_includes response.body, "visualizer_http_requests_total"
    assert_not_includes response.body, "query"
    assert_not_includes response.body, "body"
  end

  test "records queue lifecycle metrics without job arguments" do
    ActiveSupport::Notifications.instrument("enqueue.active_job", job: ApplicationJob.new) {}

    get "/metrics"

    assert_includes response.body, 'visualizer_jobs_total{job="ApplicationJob",status="enqueued"}'
    assert_not_includes response.body, "arguments"
  end
end
