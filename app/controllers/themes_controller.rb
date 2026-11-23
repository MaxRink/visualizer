# Persists the explicit light/dark choice behind the header toggle. Users who
# never toggle keep "system" and follow prefers-color-scheme.
class ThemesController < ApplicationController
  before_action :require_authentication

  def update
    skin = params[:skin].to_s.downcase
    return head :unprocessable_content unless %w[light dark system].include?(skin)

    Current.user.update!(skin: skin.capitalize)
    head :ok
  end
end
