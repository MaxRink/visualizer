class SharedShotCleanupJob < ApplicationJob
  queue_as :low

  # VISUALIZER_SHARE_TTL_HOURS overrides both defaults; self-hosted keeps links
  # for a month, the hosted service only long enough to open one.
  def perform
    SharedShot.where(created_at: ..Limits.share_ttl.ago).destroy_all
  end
end
