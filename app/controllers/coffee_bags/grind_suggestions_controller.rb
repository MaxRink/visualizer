module CoffeeBags
  class GrindSuggestionsController < ApplicationController
    before_action :require_authentication
    before_action :check_grind_suggestions!

    def create
      @coffee_bag = Current.user.coffee_bags.find(params.expect(:coffee_bag_id))
      begin
        @coffee_bag.suggest_grind
      rescue *Shots::GrindSuggestionsController::RESCUABLE_ERRORS => e
        Rails.logger.warn("grind suggestion unavailable coffee_bag=#{@coffee_bag.id} error=#{e.class}: #{e.message.to_s.truncate(200)}")
      end
      render turbo_stream: turbo_stream.replace(helpers.dom_id(@coffee_bag, :grind_suggestion), partial: "coffee_bags/grind_suggestion", locals: {coffee_bag: @coffee_bag})
    end
  end
end
