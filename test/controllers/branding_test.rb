require "test_helper"

class BrandingTest < ActionDispatch::IntegrationTest
  FORBIDDEN = [
    "visualizer.coffee",
    "miharekar",
    "miha@",
    "mr.si",
    "Upgrade to Premium",
    "Premium subscription"
  ].freeze

  test "mailers carry the instance notice and no upstream branding" do
    user = create(:user, :premium, unsubscribed_from: [])
    shot = create(:shot, user:, profile_title: "Brand test")
    messages = [
      ConfirmationsMailer.confirm(user),
      PasswordsMailer.reset(user),
      UserMailer.with(user:, shot:).shot_uploaded,
      UserMailer.with(user:).airtable_base_full,
      UserMailer.with(user:).cancelled_premium,
      UserMailer.with(user:, token: "token").oidc_link
    ]

    messages.each do |message|
      body = [message.text_part&.decoded, message.html_part&.decoded].compact.join("\n")
      body = message.body.decoded if body.blank?

      assert_includes body, Instance::NOTICE, "#{message.subject} is missing the fork notice"

      FORBIDDEN.each do |word|
        assert_not_includes [message.subject, body].join("\n"), word, "#{message.subject} mentions #{word}"
      end
    end
  end

  test "landing page and manifest use the instance identity" do
    get root_url

    assert_response :success
    assert_includes response.body, Instance::NOTICE
    FORBIDDEN.each { |word| assert_not_includes response.body, word }

    get pwa_manifest_url(format: :json)

    assert_response :success
    assert_includes response.body, Instance.name
    assert_not_includes response.body, "visualizer.coffee"
  end
end
