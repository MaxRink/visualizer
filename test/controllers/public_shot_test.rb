require "test_helper"

class PublicShotTest < ActionDispatch::IntegrationTest
  setup do
    host! "example.com"
    @owner = create(:user)
    @shot = create(:shot, user: @owner, public: false, profile_title: "Shared shot", private_notes: "owner secret", bean_notes: "shared notes")
  end

  test "anonymous visitors see a shared shot" do
    create(:shared_shot, shot: @shot, code: "AAAA", created_at: 10.minutes.ago)

    get shot_url(@shot)

    assert_response :success
    assert_includes response.body, @shot.profile_title
    assert_includes response.body, "shared notes"
  end

  test "anonymous visitors do not see an unshared shot" do
    get shot_url(@shot)

    assert_response :not_found
  end

  test "an expired share is not visible" do
    create(:shared_shot, shot: @shot, code: "BBBB", created_at: 2.hours.ago)

    get shot_url(@shot)

    assert_response :not_found
  end

  test "public shots stay visible without a share" do
    @shot.update!(public: true)

    get shot_url(@shot)

    assert_response :success
  end

  test "a shared page hides owner-only data" do
    create(:shared_shot, shot: @shot, code: "CCCC", created_at: 10.minutes.ago)
    create(:api_token, user: @owner, name: "Owner key")

    get shot_url(@shot)

    assert_response :success
    assert_not_includes response.body, @owner.email
    assert_not_includes response.body, "owner secret"
    assert_not_includes response.body, "Owner key"
    assert_not_includes response.body, "gravatar"
  end

  test "a shared shot image is served without a session" do
    @shot.image.attach(io: StringIO.new("\x89PNG\r\n\x1A\n".b + SecureRandom.random_bytes(16)), filename: "shot.png", content_type: "image/png")
    create(:shared_shot, shot: @shot, code: "DDDD", created_at: 10.minutes.ago)

    get image_shot_url(@shot)

    assert_response :success
    assert_equal "image/png", response.media_type
  end

  test "an unshared shot image is not served" do
    @shot.image.attach(io: StringIO.new("\x89PNG\r\n\x1A\n".b + SecureRandom.random_bytes(16)), filename: "shot.png", content_type: "image/png")

    get image_shot_url(@shot)

    assert_response :not_found
  end

  test "the owner still sees their own unshared shot" do
    sign_in(@owner)

    get shot_url(@shot)

    assert_response :success
  end

  test "anonymous visitors cannot mint a share" do
    assert_no_difference "SharedShot.count" do
      get share_shot_url(@shot)
    end

    assert_redirected_to new_session_url
  end

  test "a signed-in non-owner cannot share someone else's shot" do
    sign_in(create(:user))

    assert_no_difference "SharedShot.count" do
      get share_shot_url(@shot)
    end
    assert_response :not_found

    delete session_url
    get shot_url(@shot)
    assert_response :not_found
  end

  test "anonymous visitors cannot compare private shots" do
    other = create(:shot, user: @owner, public: false)

    get compare_url(@shot, other)
    assert_response :not_found

    @shot.update!(public: true)
    get compare_url(@shot, other)
    assert_response :not_found
  end

  test "anonymous visitors can compare shared and public shots" do
    create(:shared_shot, shot: @shot, code: "EEEE", created_at: 10.minutes.ago)
    other = create(:shot, user: create(:user), public: true)

    get compare_url(@shot, other)

    assert_response :success
    assert_includes response.body, "Comparison"
  end

  private

  def compare_url(shot, comparison)
    "#{shot_url(shot)}/compare/#{comparison.id}"
  end
end
