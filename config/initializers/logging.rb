require Rails.root.join("lib/logging_setup.rb")

if Rails.env.production?
  # Keep the console logger (the deployment reads docker logs) and only add the
  # AppSignal sink when it is actually configured.
  Rails.logger = LoggingSetup.production_logger
end
