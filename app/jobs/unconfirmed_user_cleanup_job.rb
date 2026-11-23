class UnconfirmedUserCleanupJob < ApplicationJob
  queue_as :low

  # Deleting accounts is a hosted-service housekeeping task. Self-hosted
  # operators manage their own users, so the job is a no-op there.
  def perform
    return if User.self_hosted?

    stale = User.where(confirmed_at: nil, disabled_at: nil, created_at: ..7.days.ago)
    stale.where(id: Shot.select(:user_id)).find_each { it.update!(disabled_at: Time.current) }
    stale.destroy_all
  end
end
