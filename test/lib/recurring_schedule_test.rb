require "test_helper"

class RecurringScheduleTest < ActiveSupport::TestCase
  SAAS_JOBS = %w[
    duplicate_creem_subscriptions_job
    duplicate_lemon_squeezy_subscriptions_job
    premium_feedback_job
    airtable_webhook_refresh_all_job
    loffee_labs_importer_job
  ].freeze

  test "hosted schedule keeps the SaaS jobs" do
    tasks = load_schedule(self_hosted: false)

    SAAS_JOBS.each { |job| assert_includes tasks.keys, job }
  end

  test "self-hosted schedule drops the SaaS jobs" do
    tasks = load_schedule(self_hosted: true)

    SAAS_JOBS.each { |job| assert_not_includes tasks.keys, job }
    assert_includes tasks.keys, "shared_shot_cleanup_job"
    assert_includes tasks.keys, "clear_solid_queue_finished_jobs"
    assert_includes tasks.keys, "tag_cleaner_job"
  end

  private

  def load_schedule(self_hosted:)
    previous = ENV["VISUALIZER_SELF_HOSTED"]
    ENV["VISUALIZER_SELF_HOSTED"] = self_hosted ? "true" : nil
    source = ERB.new(Rails.root.join("config/recurring.yml").read).result
    YAML.safe_load(source)
  ensure
    ENV["VISUALIZER_SELF_HOSTED"] = previous
  end
end
