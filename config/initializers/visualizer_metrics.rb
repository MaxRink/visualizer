# frozen_string_literal: true

if VisualizerMetrics.enabled?
  ActiveSupport::Notifications.subscribe("perform.active_job") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    status = event.payload[:exception].present? ? "error" : "performed"
    VisualizerMetrics.observe_job(event, status)
  end

  ActiveSupport::Notifications.subscribe("retry_stopped.active_job") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    VisualizerMetrics.observe_job(event, "error")
  end

  ActiveSupport::Notifications.subscribe("discard.active_job") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    VisualizerMetrics.observe_job(event, "discarded")
  end

  ActiveSupport::Notifications.subscribe("enqueue.active_job") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    VisualizerMetrics.observe_job(event, VisualizerMetrics.enqueue_status(event.payload[:job]))
  end
end
