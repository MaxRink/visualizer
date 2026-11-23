# Browser and API rate limits are protective but upstream-tuned. The hosted
# service keeps them; self-hosted installs default to off because their ingress
# already handles abuse. VISUALIZER_RATE_LIMITS=true|false overrides either way.
module RateLimits
  module_function

  def enabled?
    ENV.fetch("VISUALIZER_RATE_LIMITS") { User.self_hosted? ? "false" : "true" } != "false"
  end
end
