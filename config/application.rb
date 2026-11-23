require_relative "boot"
require_relative "../lib/bad_request_middleware"
require_relative "../lib/cloudflare_remote_ip"
require_relative "../lib/extensions/ip_addr"
require_relative "../lib/legacy_multipart_content_type"

require "rails/all"
require_relative "../app/lib/visualizer_metrics"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Visualizer
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Rails reads Active Record encryption keys from credentials only, but the
    # deployment supplies them as environment variables. This must run in the
    # class body: db:prepare loads ActiveRecord before config/initializers, and
    # the railtie reads the keys when ActiveRecord itself loads.
    %w[PRIMARY_KEY DETERMINISTIC_KEY KEY_DERIVATION_SALT].each do |name|
      value = ENV["ACTIVE_RECORD_ENCRYPTION_#{name}"]
      config.active_record.encryption.public_send("#{name.downcase}=", value) if value.present?
    end

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks misc extensions])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.active_storage.analyzers = []
    config.active_storage.resolve_model_to_route = :rails_storage_proxy
    config.active_storage.variant_processor = :disabled
    config.exceptions_app = routes
    config.log_tags = %i[request_id remote_ip]
    config.middleware.insert_after ActionDispatch::RemoteIp, CloudflareRemoteIp
    config.middleware.insert_before Rack::MethodOverride, BadRequestMiddleware
    config.middleware.insert_before BadRequestMiddleware, LegacyMultipartContentType
    config.middleware.insert_after ActionDispatch::Executor, VisualizerMetricsMiddleware if VisualizerMetrics.enabled?
    config.mission_control.jobs.http_basic_auth_enabled = false

    initializer "hotcell.variant_transformer", after: "active_storage.configs" do
      config.after_initialize { ActiveStorage.variant_transformer = HotCellImageTransformer }
    end
  end
end
