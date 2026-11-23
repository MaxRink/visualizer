require "test_helper"

class SharedShotCleanupJobTest < ActiveJob::TestCase
  test "the truth" do
    fresh = create(:shared_shot)
    old = create(:shared_shot, :old)

    SharedShotCleanupJob.perform_now

    assert SharedShot.find_by(id: fresh.id)
    assert_not SharedShot.find_by(id: old.id)
  end

  test "VISUALIZER_SHARE_TTL_HOURS overrides the ttl" do
    fresh = create(:shared_shot, code: "AAAA", created_at: 90.minutes.ago)
    stale = create(:shared_shot, code: "BBBB", created_at: 3.hours.ago)

    previous = ENV["VISUALIZER_SHARE_TTL_HOURS"]
    ENV["VISUALIZER_SHARE_TTL_HOURS"] = "2"
    begin
      SharedShotCleanupJob.perform_now
    ensure
      ENV["VISUALIZER_SHARE_TTL_HOURS"] = previous
    end

    assert SharedShot.find_by(id: fresh.id)
    assert_not SharedShot.find_by(id: stale.id)
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
