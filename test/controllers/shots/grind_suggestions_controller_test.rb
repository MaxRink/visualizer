require "test_helper"

class Shots::GrindSuggestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create(:user, :admin)
    @shot = create(:shot, user: @admin, duration: 30, grinder_setting: "15")
    host! "example.com"
    sign_in(@admin)
  end

  test "suggests grind and replaces the link" do
    probabilities = (0..6).to_h { [it.to_s, it == 1 ? 1.0 : 0.0] }
    stub_system_one(adjustment: {type: "score", probabilities:}, puck_issue: {type: "noul", noul: 0.1})
    sign_in @admin

    post shot_grind_suggestion_path(@shot), as: :turbo_stream

    assert_response :success
    assert_includes response.body, "Finer"
    assert_equal "finer", @shot.reload.grind_suggestion["direction"]
  end

  test "429 renders the retry state with 200" do
    assert_unavailable(SystemOne::Error.new("LiteLLM HTTP 429"), "429")
  end

  test "500 renders the retry state with 200" do
    assert_unavailable(SystemOne::Error.new("LiteLLM HTTP 500"), "500")
  end

  test "a timeout renders the retry state with 200" do
    assert_unavailable(Net::ReadTimeout.new("read timeout"), "Net::ReadTimeout")
  end

  test "a connection error renders the retry state with 200" do
    assert_unavailable(Errno::ECONNREFUSED.new, "Errno::ECONNREFUSED")
  end

  test "malformed JSON renders the retry state with 200" do
    assert_unavailable(SystemOne::Error.new("LiteLLM returned an invalid JSON response"), "invalid JSON")
  end

  test "nothing about the prompt or response is logged" do
    io = capture_log do
      with_system_one(SystemOne::Error.new("LiteLLM HTTP 429")) do
        post shot_grind_suggestion_path(@shot), as: :turbo_stream
      end
    end

    assert_not_includes io.string, "Answer the supplied espresso questions"
    assert_not_includes io.string, "synthetic"
    assert_includes io.string, "429"
  end

  test "non-admins are redirected" do
    user = create(:user, :premium)
    shot = create(:shot, user:, duration: 30)
    sign_in user

    post shot_grind_suggestion_path(shot), as: :turbo_stream

    assert_redirected_to shots_path
    assert_nil shot.reload.grind_suggestion
  end

  test "self-hosted non-admins with inference configured reach the action" do
    user = create(:user)
    shot = create(:shot, user:, duration: 30)
    env = {"VISUALIZER_SELF_HOSTED" => "true", "VISUALIZER_INFERENCE_BASE_URL" => "http://10.255.255.254:30681/v1/chat/completions",
           "VISUALIZER_INFERENCE_MODEL" => "auto/fast", "VISUALIZER_INFERENCE_API_KEY" => "synthetic-key"}
    previous = env.keys.index_with { ENV[it] }
    env.each { |key, value| ENV[key] = value }
    sign_in user

    with_system_one(SystemOne::Throttled.new("LiteLLM HTTP 429")) do
      post shot_grind_suggestion_path(shot), as: :turbo_stream
    end

    assert_response :success
    assert_includes response.body, "Grind suggestions are unavailable right now"
  ensure
    previous&.each { |key, value| ENV[key] = value }
  end

  private

  def assert_unavailable(error, log_fragment)
    io = capture_log do
      with_system_one(error) do
        post shot_grind_suggestion_path(@shot), as: :turbo_stream
      end
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, "Grind suggestions are unavailable right now"
    assert_includes response.body, "Suggest grind"
    assert_includes io.string, log_fragment
    assert_not_includes io.string, "Answer the supplied espresso questions"
    assert_not_includes io.string, "synthetic"
  end

  def capture_log
    original = Rails.logger
    io = StringIO.new
    Rails.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(io))
    yield
    io
  ensure
    Rails.logger = original
  end

  def with_system_one(error)
    original = SystemOne.method(:new)
    SystemOne.define_singleton_method(:new) { |**| raise error }
    yield
  ensure
    SystemOne.define_singleton_method(:new, original)
  end
end
