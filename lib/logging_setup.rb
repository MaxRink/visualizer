# Production logging always keeps STDOUT (docker logs) and only adds AppSignal
# when it has a key; AppSignal's logger silently discards lines otherwise.
module LoggingSetup
  module_function

  def production_logger(stdout: $stdout, appsignal: AppsignalConfig.configured?, formatter: nil)
    console = ActiveSupport::Logger.new(stdout)
    console.formatter = formatter || Rails.logger.formatter
    console.level = Rails.logger.level

    loggers = [console]
    loggers << Appsignal::Logger.new("rails") if appsignal

    ActiveSupport::TaggedLogging.new(ActiveSupport::BroadcastLogger.new(*loggers))
  end
end
