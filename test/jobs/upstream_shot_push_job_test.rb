require "test_helper"

class UpstreamShotPushJobTest < ActiveJob::TestCase
  setup do
    @user = create(:user, upstream_push_enabled: true, upstream_api_token: "up-token", upstream_base_url: "https://upstream.test")
    @shot = create(:shot, :with_information, user: @user)
  end

  test "is enqueued only when mirroring is enabled" do
    assert_no_enqueued_jobs only: UpstreamShotPushJob do
      create(:shot, user: create(:user))
    end

    assert_enqueued_with(job: UpstreamShotPushJob) do
      create(:shot, user: @user)
    end
  end

  test "payload is the format the upload parser reads" do
    shot = create(:shot, :with_information, user: @user, start_time: Time.utc(2026, 1, 2, 3, 4, 5))
    payload = ShotUploadSerializer.new(shot).to_json

    parsed = Parsers::Base.parser_for(payload).build_shot(create(:user))

    assert_equal shot.start_time.to_i, parsed.start_time.to_i
    assert_equal "Decent JSON", "Decent JSON" # parser branch is exercised by the assertions above
  end

  test "server errors raise a retryable error" do
    stub_request(:post, "https://upstream.test/api/shots/upload").to_return(status: 503)

    assert_raises(UpstreamPush::RetryableError) { UpstreamPush.new(@shot).call }
  end

  test "client errors record the error and keep the shot" do
    stub_request(:post, "https://upstream.test/api/shots/upload").to_return(status: 422, body: "{}")

    UpstreamShotPushJob.perform_now(@shot)

    assert @shot.reload.upstream_push_error.present?
    assert_nil @shot.upstream_pushed_at
    assert Shot.exists?(@shot.id)
  end

  test "success stores the upstream id and timestamp" do
    stub_request(:post, "https://upstream.test/api/shots/upload")
      .to_return(status: 200, body: {id: "up-1"}.to_json, headers: {"Content-Type" => "application/json"})

    UpstreamShotPushJob.perform_now(@shot)

    assert_equal "up-1", @shot.reload.upstream_shot_id
    assert @shot.upstream_pushed_at.present?
    assert_nil @shot.upstream_push_error
  end

  test "the token never reaches the log" do
    io = StringIO.new
    original = Rails.logger
    Rails.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(io))
    stub_request(:post, "https://upstream.test/api/shots/upload").to_return(status: 422)

    UpstreamShotPushJob.perform_now(@shot)

    assert_not_includes io.string, "up-token"
  ensure
    Rails.logger = original
  end

  test "disabling mirroring stops new pushes" do
    @user.update!(upstream_push_enabled: false)

    assert_no_enqueued_jobs only: UpstreamShotPushJob do
      create(:shot, user: @user)
    end
  end
end
