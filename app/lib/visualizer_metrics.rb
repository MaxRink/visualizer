# frozen_string_literal: true

require "fileutils"
require "json"
require "tempfile"

# Small Prometheus registry for the self-hosted deployment. Each web/job
# process writes a private snapshot into the shared storage mount, allowing
# Prometheus to see both Puma workers and the separate Solid Queue worker.
# Labels are bounded route/job names and never include request content.
module VisualizerMetrics
  module_function

  HTTP = Hash.new(0)
  JOBS = Hash.new(0)
  MUTEX = Mutex.new
  METHODS = %w[GET POST PUT PATCH DELETE HEAD OPTIONS CONNECT TRACE].freeze

  def metrics_dir
    ENV.fetch("VISUALIZER_METRICS_DIR", "/rails/storage/metrics")
  end

  def process_file
    role = ENV.fetch("VISUALIZER_METRICS_PROCESS", "web").gsub(/[^a-zA-Z0-9_.-]/, "_")
    File.join(metrics_dir, "#{role}-#{Process.pid}.json")
  end

  def increment(bucket, labels)
    key = labels.to_h { |name, value| [name.to_s, value.to_s] }.sort.to_h.freeze
    MUTEX.synchronize do
      bucket[key] += 1
      persist!
    end
  end

  def observe_http(request, status)
    route = request.path_parameters.values_at(:controller, :action).compact.join("#")
    route = "unmatched" if route.empty?
    method = METHODS.include?(request.request_method) ? request.request_method : "OTHER"
    status = status.to_i.between?(100, 599) ? status.to_i.to_s : "OTHER"
    increment(HTTP, method: method, route: route, status: status)
  end

  def observe_job(event, status)
    job = event.payload[:job].class.name.to_s
    job = "unknown" if job.empty?
    increment(JOBS, job: job, status: status)
  end

  def prometheus
    snapshots = Dir.glob(File.join(metrics_dir, "*.json")).filter_map do |path|
      JSON.parse(File.read(path))
    rescue Errno::ENOENT, JSON::ParserError
      nil
    end
    lines = [
      "# HELP visualizer_http_requests_total HTTP requests handled by route and status.",
      "# TYPE visualizer_http_requests_total counter"
    ]
    aggregate(snapshots, "http").each do |labels, value|
      lines << sample("visualizer_http_requests_total", labels, value)
    end
    lines << "# HELP visualizer_jobs_total Active Job lifecycle events by job and status."
    lines << "# TYPE visualizer_jobs_total counter"
    aggregate(snapshots, "jobs").each do |labels, value|
      lines << sample("visualizer_jobs_total", labels, value)
    end
    lines.join("\n") + "\n"
  end

  def aggregate(snapshots, bucket)
    snapshots.each_with_object(Hash.new(0)) do |snapshot, result|
      snapshot.fetch(bucket, []).each do |entry|
        labels = entry.fetch("labels").sort.to_h
        result[labels] += Integer(entry.fetch("value"))
      end
    rescue KeyError, TypeError, ArgumentError
      next
    end
  end

  def persist!
    FileUtils.mkdir_p(metrics_dir)
    payload = {"http" => serialize(HTTP), "jobs" => serialize(JOBS)}
    temporary = Tempfile.new(["visualizer-metrics", ".tmp"], metrics_dir)
    temporary.write(JSON.generate(payload))
    temporary.flush
    temporary.fsync
    temporary.close
    File.rename(temporary.path, process_file)
  ensure
    temporary&.unlink
  end

  def serialize(bucket)
    bucket.map { |labels, value| {"labels" => labels, "value" => value} }
  end

  def reset_for_test!
    MUTEX.synchronize do
      HTTP.clear
      JOBS.clear
      FileUtils.rm_f(process_file)
    end
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
