module Shots
  class GrindSuggestionsController < ApplicationController
    UNAVAILABLE_MESSAGE = "Grind suggestions are unavailable right now, try again later."
    RESCUABLE_ERRORS = [
      SystemOne::Error,
      Timeout::Error,
      SocketError,
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Errno::EHOSTUNREACH
    ].freeze

    before_action :require_authentication
    before_action :check_admin!

    def create
      @shot = Current.user.shots.find(params.expect(:shot_id))
      @shot.suggest_grind_now
      render_suggestion
    rescue *RESCUABLE_ERRORS => e
      # Status code only: never the prompt or the model's response body.
      Rails.logger.warn("grind suggestion unavailable shot=#{params[:shot_id]} error=#{e.class}: #{e.message.to_s.truncate(200)}")
      render_suggestion(UNAVAILABLE_MESSAGE)
    end

    private

    def render_suggestion(notice = nil)
      render turbo_stream: turbo_stream.replace(
        helpers.dom_id(@shot, :grind_suggestion),
        partial: "shots/grind_suggestion",
        locals: {shot: @shot, notice:}
      )
    end
  end
end
