# frozen_string_literal: true

require "test_helper"

class OpenTelemetryAttributeTypesTest < ActiveSupport::TestCase
  test "normalizes symbol attributes before the SDK validates them" do
    span_class = Class.new do
      attr_reader :attributes

      def initialize
        @attributes = {}
      end

      def set_attribute(key, value)
        @attributes[key] = value
      end
    end
    span_class.prepend(VisualizerOpenTelemetryAttributeTypes)
    span = span_class.new

    span.set_attribute("messaging.destination", :realtime)

    assert_equal "realtime", span.attributes["messaging.destination"]
  end
end
