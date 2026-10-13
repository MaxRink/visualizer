# frozen_string_literal: true

require "json"
require "prometheus_exporter/client"

# Privacy-bounded custom metrics sent to the maintained Prometheus Exporter
# collector. The collector aggregates observations from Puma and Solid Queue
# processes; this app only queues non-sensitive events and never stores them.
module VisualizerMetrics
  module_function

  METHODS = %w[GET POST PUT PATCH DELETE HEAD OPTIONS CONNECT TRACE].freeze

  def http_metric
    @http_metric ||= client.register(
      :counter,
      "visualizer_http_requests_total",
      "HTTP requests handled by route and status."
    )
  end

  def jobs_metric
    @jobs_metric ||= client.register(
      :counter,
      "visualizer_jobs_total",
      "Active Job lifecycle events by job and status."
    )
  end

  def http_duration_metric
    @http_duration_metric ||= client.register(
      :histogram,
      "visualizer_http_request_duration_seconds",
      "HTTP request duration in seconds."
    )
  end

  def client
    @client ||= PrometheusExporter::Client.new(
      host: ENV.fetch("PROMETHEUS_EXPORTER_HOST", "localhost"),
      port: Integer(ENV.fetch("PROMETHEUS_EXPORTER_PORT", "9394"), 10)
    )
  end

  def client=(value)
    @client = value
    @http_metric = nil
    @http_duration_metric = nil
    @jobs_metric = nil
  end

  def observe_http(request, status, duration_seconds = nil)
    route = request.path_parameters.values_at(:controller, :action).compact.join("#")
    route = "unmatched" if route.empty?
    method = METHODS.include?(request.request_method) ? request.request_method : "OTHER"
    status = status.to_i.between?(100, 599) ? status.to_i.to_s : "OTHER"
    http_metric.increment(method: method, route: route, status: status)
    if duration_seconds
      http_duration_metric.observe(duration_seconds.to_f, method: method, route: route, status: status)
    end
  rescue StandardError => e
    Rails.logger.warn("Prometheus Exporter unavailable for HTTP metric: #{e.class}") if defined?(Rails)
  end

  def observe_job(event, status)
    job = event.payload[:job].class.name.to_s
    job = "unknown" if job.empty?
    jobs_metric.increment(job: job, status: status.to_s)
  rescue StandardError => e
    Rails.logger.warn("Prometheus Exporter unavailable for job metric: #{e.class}") if defined?(Rails)
  end
end

class VisualizerMetricsMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    status, headers, body = @app.call(env)
    request = ActionDispatch::Request.new(env)
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
    VisualizerMetrics.observe_http(request, status, duration)
    [status, headers, body]
  rescue Exception
    request = ActionDispatch::Request.new(env)
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
    VisualizerMetrics.observe_http(request, 500, duration)
    raise
  end
end
