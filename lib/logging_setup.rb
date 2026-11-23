# Production logging always keeps STDOUT (docker logs) and only adds AppSignal
# when it has a key; AppSignal's logger silently discards lines otherwise.
module LoggingSetup
  module_function

  def production_logger(stdout: $stdout, appsignal: appsignal_configured?, formatter: nil)
    console = ActiveSupport::Logger.new(stdout)
    console.formatter = formatter || Rails.logger.formatter
    console.level = Rails.logger.level

    loggers = [console]
    loggers << Appsignal::Logger.new("rails") if appsignal

    ActiveSupport::TaggedLogging.new(ActiveSupport::BroadcastLogger.new(*loggers))
  end
  # Inlined rather than referencing AppsignalConfig: autoloaded constants from
  # app/lib are not loadable while initializers run, which is where this is used
  # (and why the previous version failed during assets:precompile).
  def appsignal_configured?
    return true if ENV["APPSIGNAL_PUSH_API_KEY"].present?

    Rails.application.credentials.appsignal.present?
  rescue StandardError
    false
  end
end
