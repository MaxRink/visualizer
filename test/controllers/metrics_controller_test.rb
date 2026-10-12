require "test_helper"

class MetricsControllerTest < ActiveSupport::TestCase
  FakeMetric = Struct.new(:observations) do
    def increment(labels = nil, value = 1)
      observations << [labels, value]
    end
  end

  class FakeClient
    attr_reader :metrics

    def initialize
      @metrics = {}
    end

    def register(type, name, _help)
      @metrics[name] = FakeMetric.new([])
    end
  end

  Request = Struct.new(:path_parameters, :request_method)

  setup do
    @client = FakeClient.new
    VisualizerMetrics.client = @client
  end

  teardown do
    VisualizerMetrics.client = nil
  end

  test "exports only bounded HTTP labels" do
    VisualizerMetrics.observe_http(Request.new({controller: "metrics", action: "show"}, "BREW"), 700)

    observations = @client.metrics.fetch("visualizer_http_requests_total").observations
    assert_equal [[{method: "OTHER", route: "metrics#show", status: "OTHER"}, 1]], observations
  end

  test "exports bounded job labels without job arguments" do
    event = ActiveSupport::Notifications::Event.new(
      "enqueue.active_job", 0, 0, "id", job: ApplicationJob.new, arguments: ["private"]
    )
    VisualizerMetrics.observe_job(event, "enqueued")

    observations = @client.metrics.fetch("visualizer_jobs_total").observations
    assert_equal [[{job: "ApplicationJob", status: "enqueued"}, 1]], observations
    assert_not_includes observations.flatten, "private"
  end

  test "collector failure does not fail application work" do
    failing = Object.new
    def failing.register(*)
      raise IOError, "collector unavailable"
    end
    VisualizerMetrics.client = failing

    assert_nothing_raised do
      VisualizerMetrics.observe_http(Request.new({}, "GET"), 200)
      VisualizerMetrics.observe_job(
        ActiveSupport::Notifications::Event.new("enqueue.active_job", 0, 0, "id", job: ApplicationJob.new),
        "enqueued"
      )
    end
  end
end
