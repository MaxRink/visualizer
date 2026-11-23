# Builds the Decent JSON shot file that Parsers::DecentJson reads, from the
# data this app already stored for the shot. This is the same format the
# public /api/shots/upload endpoint accepts, so the upstream service parses it
# with its normal upload path instead of a bespoke format.
class ShotUploadSerializer
  def initialize(shot)
    @shot = shot
    @information = shot.information
  end

  def to_json(*_args)
    payload.to_json
  end

  def payload
    raise ArgumentError, "shot has no brew data to export" if @information.blank? || @information.timeframe.blank?

    data = @information.data || {}
    {
      timestamp: @shot.start_time.to_i,
      elapsed: @information.timeframe,
      profile: @information.profile_fields.presence || {"title" => @shot.profile_title},
      pressure: series(data, "espresso_pressure", goal: "espresso_pressure_goal"),
      flow: series(data, "espresso_flow", by_weight: "espresso_flow_weight", goal: "espresso_flow_goal"),
      temperature: {
        mix: data["espresso_temperature_mix"],
        basket: data["espresso_temperature_basket"],
        goal: data["espresso_temperature_goal"]
      }.compact,
      totals: {weight: data["espresso_weight"], water_dispensed: data["espresso_water_dispensed"]}.compact,
      state_change: data["espresso_state_change"],
      app: {data: {settings: @information.extra.merge(@information.profile_fields)}}
    }.compact
  end

  private

  def series(data, value_key, **named)
    series = {value_key.delete_prefix("espresso_") => data[value_key]}
    named.each { |name, key| series[name.to_s] = data[key] }
    series.compact
  end
end
