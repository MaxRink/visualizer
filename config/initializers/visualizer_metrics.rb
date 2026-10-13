# frozen_string_literal: true

ActiveSupport::Notifications.subscribe("perform.active_job") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  VisualizerMetrics.observe_job(event, event.payload[:exception].present? ? "error" : "success")
end

ActiveSupport::Notifications.subscribe("enqueue.active_job") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  VisualizerMetrics.observe_job(event, "enqueued")
end
