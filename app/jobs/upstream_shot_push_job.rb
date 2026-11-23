class UpstreamShotPushJob < ApplicationJob
  queue_as :low

  retry_on UpstreamPush::RetryableError, wait: :polynomially_longer, attempts: 5 do |job, error|
    shot = job.arguments.first
    shot.update!(upstream_push_error: error.message.truncate(500)) if shot&.persisted?
  end

  def perform(shot)
    return unless shot.user&.upstream_push_enabled?

    result = UpstreamPush.new(shot).call
    shot.update!(upstream_pushed_at: Time.current, upstream_shot_id: result["id"], upstream_push_error: nil)
  rescue UpstreamPush::PermanentError => e
    shot.update!(upstream_push_error: e.message.truncate(500))
  end
end
