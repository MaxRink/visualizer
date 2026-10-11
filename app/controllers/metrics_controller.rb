# frozen_string_literal: true

class MetricsController < ActionController::Metal
  def show
    self.content_type = "text/plain; version=0.0.4; charset=utf-8"
    self.response_body = VisualizerMetrics.prometheus
  end
end
