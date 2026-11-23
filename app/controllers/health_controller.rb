class HealthController < ActionController::Base # rubocop:disable Rails/ApplicationController
  def show
    database = database_reachable?

    render json: {
      status: database ? "ok" : "unavailable",
      fork: Instance.fork?,
      self_hosted: Instance.self_hosted?,
      version: Instance.version,
      commit: Instance.commit,
      database:,
      time: Time.current.iso8601
    }, status: database ? :ok : :service_unavailable
  end

  private

  def database_reachable?
    ActiveRecord::Base.connection.select_value("SELECT 1") == 1
  rescue ActiveRecord::ActiveRecordError
    false
  end
end
