class HomeController < ApplicationController
  def show
    redirect_to shots_path if Current.user
  end

  def privacy; end
end
