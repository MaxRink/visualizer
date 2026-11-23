class UploadKeysController < ApplicationController
  before_action :require_authentication

  def create
    Current.user.rotate_upload_key!

    redirect_to edit_profile_path, notice: "A new upload key was generated."
  end

  def destroy
    Current.user.api_tokens.active.find_each(&:revoke!)

    redirect_to edit_profile_path, notice: "Your upload key was revoked."
  end
end
