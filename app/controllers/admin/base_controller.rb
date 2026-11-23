module Admin
  class BaseController < ApplicationController
    before_action :require_admin

    private

    # 404 rather than a redirect so non-admins cannot probe for the area.
    def require_admin
      head :not_found unless Current.user&.admin?
    end

    def audit(action, target, **details)
      Rails.logger.info({
        event: "admin.#{action}",
        actor_id: Current.user.id,
        actor_email: Current.user.email,
        target_id: target.id,
        target_email: target.email
      }.merge(details).to_json)
    end
  end
end
