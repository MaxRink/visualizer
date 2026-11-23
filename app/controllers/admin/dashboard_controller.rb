module Admin
  class DashboardController < BaseController
    def show
      @counts = {
        users: User.count,
        shots: Shot.count,
        coffee_bags: CoffeeBag.count,
        roasters: Roaster.count
      }
      @storage_bytes = ActiveStorage::Blob.sum(:byte_size)
      @oldest_shot_at = Shot.minimum(:start_time)
      @newest_shot_at = Shot.maximum(:start_time)
    end
  end
end
