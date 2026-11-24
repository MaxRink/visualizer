class GrindSuggestionJob < ApplicationJob
  # A bulk upload enqueues one job per shot; the gateway's per-deployment
  # parallel limit answered the burst with 429s. Run inference jobs one at a
  # time and retry throttling with a growing pause.
  limits_concurrency to: 1, key: ->(*) { "inference" }, group: "Inference", duration: 5.minutes
  retry_on SystemOne::Throttled, wait: :polynomially_longer, attempts: 5
  def perform(shot)
    shot.suggest_grind_now
  end
end
