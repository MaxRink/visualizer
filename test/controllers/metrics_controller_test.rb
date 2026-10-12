require "test_helper"
require "tmpdir"

class MetricsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "visualizer.test"
    @metrics_dir = Dir.mktmpdir("visualizer-metrics")
    ENV["VISUALIZER_METRICS_DIR"] = @metrics_dir
    ENV["VISUALIZER_METRICS_PROCESS"] = "test-web"
    VisualizerMetrics.reset_for_test!
  end

  teardown do
    FileUtils.remove_entry(@metrics_dir)
    ENV.delete("VISUALIZER_METRICS_DIR")
    ENV.delete("VISUALIZER_METRICS_PROCESS")
  end

  test "exports bounded HTTP metrics without request content" do
    get "/metrics"

    assert_response :success
    assert_equal "text/plain; version=0.0.4", response.media_type
    assert_includes response.body, "visualizer_http_requests_total"
    assert_not_includes response.body, "query"
    assert_not_includes response.body, "body"
  end

  test "aggregates queue lifecycle metrics from separate worker files" do
    ActiveSupport::Notifications.instrument("enqueue.active_job", job: ApplicationJob.new) {}

    pid = fork do
      ENV["VISUALIZER_METRICS_PROCESS"] = "test-worker"
      VisualizerMetrics.reset_for_test!
      ActiveSupport::Notifications.instrument("enqueue.active_job", job: ApplicationJob.new) {}
      exit!
    end
    Process.wait(pid)

    get "/metrics"

    assert_includes response.body, 'visualizer_jobs_total{job="ApplicationJob",status="enqueued"} 2'
    assert_not_includes response.body, "arguments"
  end
end
