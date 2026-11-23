# Facts about this build that the UI and /health both read, so the notice and
# the machine-readable status cannot drift apart.
module Instance
  NOTICE = "This instance is a self-hosted Visualizer fork. It is not affiliated with the upstream project and has no accounts, billing, cloud sync, or telemetry.".freeze

  module_function

  def fork?
    true
  end

  def self_hosted?
    User.self_hosted?
  end

  def version
    ENV.fetch("APP_VERSION", "unknown")
  end

  def commit
    ENV["APP_COMMIT"].presence || ENV["GIT_REVISION"].presence || revision_file.presence || "unknown"
  end

  def revision_file
    path = Rails.root.join("REVISION")
    path.read.strip if path.exist?
  end
end
