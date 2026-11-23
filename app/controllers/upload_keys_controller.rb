class UploadKeysController < ApplicationController
  before_action :require_authentication

  def create
    name = params[:name].to_s.squish.presence || "Upload key"

    Current.user.api_tokens.create!(name:)
    redirect_to edit_profile_path, notice: "Upload key created."
  end

  def destroy
    key = Current.user.api_tokens.find(params.expect(:id))
    key.revoke!

    redirect_to edit_profile_path, notice: "Upload key revoked."
  end
end
