class ProfilesController < ApplicationController
  before_action :require_authentication
  before_action :set_profile
  before_action :set_authorized_applications

  def edit; end

  def update
    attributes = profile_params
    token = attributes[:upstream_api_token]
    attributes = attributes.except(:upstream_api_token) if token.blank?

    if @profile.update(attributes)
      flash[:notice] = "Profile successfully updated."
      redirect_to shots_path(format: :html)
    else
      respond_to do
        it.turbo_stream { render turbo_stream: turbo_stream.replace(@profile, partial: "form", locals: {profile: @profile}) }
        it.html { render :edit }
      end
    end
  end

  def test_upstream_push
    result = UpstreamPush.test(@profile)

    if result == true
      @profile.update!(upstream_push_checked_at: Time.current)
      redirect_to edit_profile_path, notice: "Upstream accepted the token."
    else
      redirect_to edit_profile_path, alert: "Upstream rejected the token (#{result})."
    end
  end

  def clear_upstream_token
    @profile.update!(upstream_api_token: nil, upstream_push_enabled: false)
    redirect_to edit_profile_path, notice: "Upstream token cleared and mirroring disabled."
  end

  def reset_chart_settings
    @profile.update(chart_settings: nil)
    flash[:notice] = "Chart settings were reset to default."
    redirect_to edit_profile_path
  end

  def disconnect_airtable
    airtables = @profile.identities.by_provider(:airtable)
    return unless airtables.exists?

    airtables.destroy_all
    redirect_to edit_profile_path, notice: "Airtable disconnected."
  end

  def disconnect_oidc
    identity = @profile.oidc_identity
    return redirect_to edit_profile_path, alert: "No OpenID Connect account is linked." unless identity

    if @profile.would_lock_out?(identity)
      flash[:alert] = "You cannot unlink your only way to sign in. Add a passkey or set a password first."
      return redirect_to edit_profile_path
    end

    identity.destroy!
    redirect_to edit_profile_path, notice: "OpenID Connect account unlinked."
  end

  private

  def set_profile
    @profile = Current.user
    @upload_keys = Current.user.upload_keys
    @shot_count = Current.user.shots.count
    @storage_bytes = UserStorage.new(Current.user).bytes
    @upstream_last_push = Current.user.shots.maximum(:upstream_pushed_at)
    @upstream_last_error = Current.user.shots.where.not(upstream_push_error: nil).order(updated_at: :desc).pick(:upstream_push_error)
  end

  def set_authorized_applications
    @authorized_applications = Doorkeeper.config.application_model.authorized_for(Current.user)
  end

  def profile_params
    allowed_params = %i[avatar name timezone temperature_unit date_format skin public hide_shot_times beta unified_chart]
    allowed_params += %i[upstream_push_enabled upstream_base_url upstream_api_token]
    allowed_params << %i[github supporter developer] if Current.user.admin?
    allowed_params << %i[coffee_management_enabled journal_enabled] if Current.user.premium?
    notification_settings = {unsubscribed_from: User::EMAIL_NOTIFICATIONS - (params[:user][:email_notifications] || [])}

    params.expect(user: allowed_params).merge(chart_settings).merge(notification_settings)
  end

  def chart_settings
    return unless @profile.premium?

    settings = ChartSettings::DEFAULT.keys.index_with do
      {
        "color" => params["user"]["#{it}-color"],
        "type" => params["user"]["#{it}-type"],
        "dashed" => ActiveModel::Type::Boolean.new.cast(params["user"]["#{it}-dashed"]),
        "hidden" => ActiveModel::Type::Boolean.new.cast(params["user"]["#{it}-hidden"]),
        "secondary_axis" => ActiveModel::Type::Boolean.new.cast(params["user"]["#{it}-secondary-axis"])
      }
    end

    {chart_settings: settings}
  end
end
