# frozen_string_literal: true

# Keep request metrics on the private monitoring network. The exporter process
# is separate from the web process, so the client forwards only aggregate
# timings, controller/action names and response status; it never sends bodies,
# query strings or user identifiers.
unless Rails.env.test?
  require "prometheus_exporter/middleware"
  require "prometheus_exporter/client"

  PrometheusExporter::Client.default = PrometheusExporter::Client.new(
    host: ENV.fetch("PROMETHEUS_EXPORTER_HOST", "localhost"),
    port: Integer(ENV.fetch("PROMETHEUS_EXPORTER_PORT", "9394"), 10)
  )

  Rails.application.middleware.unshift PrometheusExporter::Middleware
end
