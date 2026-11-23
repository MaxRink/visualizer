class UserMailerPreview < ActionMailer::Preview
  def shot_uploaded
    user = User.admin
    shot = user.shots.order("RANDOM()").first
    UserMailer.with(user:, shot:).shot_uploaded
  end

  %i[cancelled_premium airtable_base_full].each do |email|
    define_method(email) do
      user = User.order("RANDOM()").first
      UserMailer.with(user:).public_send(email)
    end
  end
end
