# Tunables that used to be hard-coded upstream limits. Defaults keep the
# hosted behaviour; self-hosted installs get more headroom, and every value can
# be pinned with an environment variable.
module Limits
  module_function

  def api_max_items
    ENV.fetch("VISUALIZER_API_MAX_ITEMS", User.self_hosted? ? 1000 : 100).to_i
  end

  def feed_items
    ENV.fetch("VISUALIZER_FEED_ITEMS", 30).to_i
  end

  def share_ttl
    hours = ENV["VISUALIZER_SHARE_TTL_HOURS"].to_i
    return hours.hours if hours.positive?

    User.self_hosted? ? 30.days : 1.hour
  end

  def max_upload_bytes
    ENV.fetch("VISUALIZER_MAX_UPLOAD_MB", 10).to_i.megabytes
  end

  def max_datapoints
    ENV.fetch("VISUALIZER_MAX_DATAPOINTS", 20_000).to_i
  end

  def journal_max_batch
    ENV.fetch("VISUALIZER_JOURNAL_MAX_BATCH", 100).to_i
  end
end
