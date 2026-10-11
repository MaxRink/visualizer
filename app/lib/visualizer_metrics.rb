# frozen_string_literal: true

# Small, dependency-free Prometheus registry for the self-hosted deployment.
# Labels are deliberately bounded route/job names and never include request
# paths, query strings, bodies, users, uploads, or job arguments.
module VisualizerMetrics
  module_function

  HTTP = Hash.new(0)
  JOBS = Hash.new(0)
  MUTEX = Mutex.new

  def increment(bucket, labels)
    key = labels.sort_by { |name, _| name.to_s }.to_h
    MUTEX.synchronize { bucket[key.freeze] += 1 }
  end

  def observe_http(request, status)
    route = request.path_parameters.values_at(:controller, :action).compact.join("#")
    route = "unmatched" if route.empty?
    increment(HTTP, method: request.request_method, route: route, status: status.to_i)
  end

  def observe_job(event, status)
    job = event.payload[:job].class.name.to_s
    job = "unknown" if job.empty?
    increment(JOBS, job: job, status: status)
  end

  def prometheus
    lines = [
      "# HELP visualizer_http_requests_total HTTP requests handled by route and status.",
      "# TYPE visualizer_http_requests_total counter"
    ]
    MUTEX.synchronize do
      HTTP.each { |labels, value| lines << sample("visualizer_http_requests_total", labels, value) }
      lines << "# HELP visualizer_jobs_total Active Job lifecycle events by job and status."
      lines << "# TYPE visualizer_jobs_total counter"
      JOBS.each { |labels, value| lines << sample("visualizer_jobs_total", labels, value) }
    end
    lines.join("\n") + "\n"
  end

  def sample(name, labels, value)
    rendered = labels.map { |key, item| %(#{key}="#{item.to_s.gsub('\\', '\\\\').gsub('"', '\\"')}") }.join(",")
    "#{name}{#{rendered}} #{value}"
  end
end

class VisualizerMetricsMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    request = ActionDispatch::Request.new(env)
    VisualizerMetrics.observe_http(request, status) unless request.path == "/metrics"
    [status, headers, body]
  rescue Exception
    request = ActionDispatch::Request.new(env)
    VisualizerMetrics.observe_http(request, 500) unless request.path == "/metrics"
    raise
  end
end
