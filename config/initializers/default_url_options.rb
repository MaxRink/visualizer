defaults = {
  development: {host: "visualizer.localhost:3000", protocol: "http"},
  test: {host: "visualizer.test", protocol: "https"},
  production: {host: ENV.fetch("APP_HOST", "localhost"), protocol: ENV.fetch("APP_PROTOCOL", "https")}
}.freeze

Rails.application.routes.default_url_options = defaults.fetch(Rails.env.to_sym)
