require "test_helper"

module Admin
  class AuditLoggingTest < ActionDispatch::IntegrationTest
    test "user actions are written through Rails.logger" do
      admin = create(:user, :admin)
      target = create(:user)
      sign_in(admin)
      io = StringIO.new
      original = Rails.logger
      Rails.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(io))

      post promote_admin_user_url(target)

      assert_redirected_to admin_users_url
      assert_includes io.string, "admin.user.promote"
      assert_includes io.string, admin.id
      assert_includes io.string, target.id
    ensure
      Rails.logger = original
    end
  end
end
