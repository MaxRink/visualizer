require "test_helper"

class SharedShotCleanupJobTest < ActiveJob::TestCase
  test "the truth" do
    fresh = create(:shared_shot)
    old = create(:shared_shot, :old)

    SharedShotCleanupJob.perform_now

    assert SharedShot.find_by(id: fresh.id)
    assert_not SharedShot.find_by(id: old.id)
  end

  test "self-hosted installs keep share codes for 30 days" do
    recent = create(:shared_shot, created_at: 2.days.ago)

    previous = ENV["VISUALIZER_SELF_HOSTED"]
    ENV["VISUALIZER_SELF_HOSTED"] = "true"
    begin
      SharedShotCleanupJob.perform_now
    ensure
      ENV["VISUALIZER_SELF_HOSTED"] = previous
    end

    assert SharedShot.find_by(id: recent.id)
  end

  test "self-hosted installs still expire share codes after 30 days" do
    stale = create(:shared_shot, created_at: 31.days.ago)

    previous = ENV["VISUALIZER_SELF_HOSTED"]
    ENV["VISUALIZER_SELF_HOSTED"] = "true"
    begin
      SharedShotCleanupJob.perform_now
    ensure
      ENV["VISUALIZER_SELF_HOSTED"] = previous
    end

    assert_not SharedShot.find_by(id: stale.id)
  end
end
