class DisableExpiredPremiumCoffeeManagementJob < ApplicationJob
  queue_as :low

  def perform
    return if User.self_hosted?

    User.where(premium_expires_at: ..Time.current, supporter: false, coffee_management_enabled: true).find_each do |user|
      user.update!(coffee_management_enabled: false)
    end
  end
end
