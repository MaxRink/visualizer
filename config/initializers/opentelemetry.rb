# frozen_string_literal: true

require "opentelemetry/sdk"
require "opentelemetry/instrumentation/rails"
require "opentelemetry/exporter/otlp"

# OpenTelemetry attributes accept strings and numbers, while ActiveSupport's
# Action Cable instrumentation can pass a Symbol for messaging.destination.
# Normalize that scalar at the SDK boundary so the exporter never logs a type
# error or drops the attribute.
module VisualizerOpenTelemetryAttributeTypes
  def set_attribute(key, value)
    value = value.to_s if value.is_a?(Symbol)
    super
  end
end

OpenTelemetry::SDK::Trace::Span.prepend(VisualizerOpenTelemetryAttributeTypes)

class VisualizerPrivacySpanProcessor < OpenTelemetry::SDK::Trace::SpanProcessor
  SENSITIVE_KEYS = %w[
    url.query
    db.statement
    db.query.text
    email.message_id
    email.subject
    email.to.address
    email.from.address
    email.cc.address
    email.bcc.address
    email.body
    http.request.body
    http.response.body
    messaging.message.body
  ].freeze

  def on_finishing(span)
    # Span#on_finishing runs while the SDK span mutex is held. The SDK exposes
    # no public delete operation, so mutate its attribute hash in this hook;
    # the locked SDK version is pinned in Gemfile.lock.
    attributes = span.instance_variable_get(:@attributes)
    SENSITIVE_KEYS.each { |key| attributes.delete(key) if attributes&.key?(key) }
  end
end

OpenTelemetry::SDK.configure do |config|
  config.service_name = ENV.fetch("OTEL_SERVICE_NAME", "visualizer")
  config.add_span_processor(VisualizerPrivacySpanProcessor.new)
  if ENV.fetch("OTEL_TRACES_EXPORTER", "otlp") != "none"
    exporter = OpenTelemetry::Exporter::OTLP::Exporter.new
    config.add_span_processor(
      OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(exporter)
    )
  end
  # Rails instrumentation covers request, controller, Active Record, Active
  # Job, Active Storage and mail timings. SQL/query, mail and URL content is
  # removed at span finalization before the exporter receives it.
  config.use_all
end
