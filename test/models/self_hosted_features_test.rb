require "test_helper"

# VISUALIZER_SELF_HOSTED=true is the single switch that gives every user the
# premium feature set; unset, the upstream gates apply unchanged.
class SelfHostedFeaturesTest < ActiveJob::TestCase
  INFERENCE_ENV = {
    "VISUALIZER_INFERENCE_BASE_URL" => "http://10.255.255.254:30681/v1/chat/completions",
    "VISUALIZER_INFERENCE_MODEL" => "auto/fast",
    "VISUALIZER_INFERENCE_API_KEY" => "synthetic-key"
  }.freeze

  test "grind suggestions stay admin-only unless self-hosted with inference configured" do
    user = create(:user)
    admin = create(:user, :admin)

    with_env("VISUALIZER_SELF_HOSTED" => nil, **INFERENCE_ENV) do
      assert admin.grind_suggestions?
      assert_not user.grind_suggestions?
    end
    with_env("VISUALIZER_SELF_HOSTED" => "true", **INFERENCE_ENV.transform_values { nil }) do
      assert_not user.grind_suggestions?
    end
    with_env("VISUALIZER_SELF_HOSTED" => "true", **INFERENCE_ENV) do
      assert user.grind_suggestions?
    end
  end

  test "a self-hosted non-admin shot enqueues a grind suggestion" do
    user = create(:user)

    with_env("VISUALIZER_SELF_HOSTED" => "true", **INFERENCE_ENV) do
      assert_enqueued_with(job: GrindSuggestionJob) { create(:shot, user:, duration: 30) }
    end
  end

  test "inference jobs share one concurrency slot and retry throttling" do
    [GrindSuggestionJob, CoffeeBag::SuggestGrindJob].each do |job|
      assert_equal 1, job.concurrency_limit
      assert_equal "Inference", job.concurrency_group
      assert_includes job.rescue_handlers.map(&:first), "SystemOne::Throttled"
    end
  end

  test "billing follow-up jobs do nothing when self-hosted" do
    user = create(:user, premium_expires_at: 4.days.ago, coffee_management_enabled: true)

    with_env("VISUALIZER_SELF_HOSTED" => "true") do
      assert_no_enqueued_jobs(only: ActionMailer::MailDeliveryJob) { PremiumFeedbackJob.perform_now }
      DisableExpiredPremiumCoffeeManagementJob.perform_now
    end

    assert_equal [], user.reload.communication
    assert user.coffee_management_enabled
  end

  test "turbo broadcast queue names are strings for OpenTelemetry" do
    [Turbo::Streams::BroadcastJob, Turbo::Streams::ActionBroadcastJob, Turbo::Streams::BroadcastStreamJob].each do |job|
      assert_equal "real_time", job.queue_name
    end
  end

  test "mail delivery retries relay timeouts" do
    handlers = ActionMailer::MailDeliveryJob.rescue_handlers.map(&:first)

    assert_includes handlers, "Net::ReadTimeout"
    assert_includes handlers, "Net::OpenTimeout"
  end

  private

  def with_env(values)
    previous = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end
end
