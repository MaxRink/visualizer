# frozen_string_literal: true

# The exporter runs as a separate, least-privileged container.  Keep the
# client opt-in so local development and tests do not attempt network I/O.
if Rails.env.production? && ENV["PROMETHEUS_EXPORTER_HOST"].present?
  require "prometheus_exporter"
  require "prometheus_exporter/client"
  require "prometheus_exporter/middleware"

  exporter_client = PrometheusExporter::Client.new(
    host: ENV.fetch("PROMETHEUS_EXPORTER_HOST"),
    port: Integer(ENV.fetch("PROMETHEUS_EXPORTER_PORT", "9394")),
  )

  # The upstream middleware emits bounded controller/action/status labels. It
  # does not include request paths, query strings, user identifiers or body
  # content, so private URLs and high-cardinality values stay out of metrics.
  Rails.application.config.middleware.insert_before(
    0,
    PrometheusExporter::Middleware,
    instrument: :alias_method,
    client: exporter_client,
  )
end
