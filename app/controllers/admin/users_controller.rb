module Admin
  class UsersController < BaseController
    PER_PAGE = 50

    before_action :set_user, only: %i[promote demote disable enable revoke_upload_key destroy]

    def index
      @page = [params[:page].to_i, 1].max
      users = User.order(:created_at).includes(:identities).offset((@page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
      @has_next = users.size > PER_PAGE
      @users = users.first(PER_PAGE)

      ids = @users.map(&:id)
      @shot_counts = Shot.where(user_id: ids).group(:user_id).count
      @last_signed_in_at = Session.where(user_id: ids).group(:user_id).maximum(:created_at)
      @upload_key_counts = ApiToken.active.where(user_id: ids).group(:user_id).count
    end

    def promote
      @user.update!(admin: true)
      audit("user.promote", @user)
      redirect_to admin_users_path, notice: "#{@user.email} is now an admin."
    end

    def demote
      return refuse_last_admin unless @user.demote_admin!

      audit("user.demote", @user)
      redirect_to admin_users_path, notice: "#{@user.email} is no longer an admin."
    end

    def disable
      return refuse_last_admin unless @user.disable!

      audit("user.disable", @user)
      redirect_to admin_users_path, notice: "#{@user.email} is disabled."
    end

    def enable
      @user.update!(disabled_at: nil)
      audit("user.enable", @user)
      redirect_to admin_users_path, notice: "#{@user.email} is enabled."
    end

    def revoke_upload_key
      revoked = @user.api_tokens.active.count
      @user.api_tokens.active.find_each(&:revoke!)
      audit("user.revoke_upload_key", @user, revoked:)
      redirect_to admin_users_path, notice: "Revoked #{revoked} upload key(s) for #{@user.email}."
    end

    def destroy
      shots = @user.shots.count
      email = @user.email
      @user.destroy_unless_last_admin!
      audit("user.destroy", @user, shots_kept: shots)
      redirect_to admin_users_path, notice: "#{email} was deleted. #{shots} shot(s) were kept without an owner."
    rescue User::LastAdminError
      refuse_last_admin
    end

    private

    def set_user
      @user = User.find_by(id: params[:id])
      head :not_found unless @user
    end

    def refuse_last_admin
      redirect_to admin_users_path, alert: "You cannot remove the last admin."
    end
  end
end
