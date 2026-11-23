class SharedShotCleanupJob < ApplicationJob
  queue_as :low

  # Hosted installs only need a share code long enough for the recipient to
  # open it; self-hosted installations keep links around for a month.
  TTL = 1.hour
  SELF_HOSTED_TTL = 30.days

  def perform
    SharedShot.where(created_at: ..ttl.ago).destroy_all
  end

  private

  def ttl
    User.self_hosted? ? SELF_HOSTED_TTL : TTL
  end
end
