# Facts about this build that the UI and /health both read, so the notice and
# the machine-readable status cannot drift apart.
module Instance
  NOTICE = "This instance is a self-hosted Visualizer fork. It is not affiliated with the upstream project and has no accounts, billing, cloud sync, or telemetry.".freeze

  module_function

  def name
    ENV.fetch("APP_NAME", "Visualizer")
  end

  # Never a hard-coded upstream host: APP_URL wins, otherwise the configured
  # default URL options for this deployment.
  def url
    ENV["APP_URL"].presence || configured_url.presence || "http://localhost:3000"
  end

  def host
    URI.parse(url).host.presence || "localhost"
  rescue URI::InvalidURIError
    "localhost"
  end

  def configured_url
    options = Rails.application.config.action_mailer.default_url_options || {}
    return if options[:host].blank?

    "#{options[:protocol] || "https"}://#{options[:host]}"
  end

  def fork?
    true
  end

  def self_hosted?
    User.self_hosted?
  end

  # Precedence: explicit environment, then a REVISION file baked into the image,
  # then git (read once at boot, see config/initializers/instance_metadata.rb).
  def version
    ENV["APP_VERSION"].presence || revision_file.presence || git_describe.presence || "unknown"
  end

  def commit
    ENV["APP_COMMIT"].presence || ENV["GIT_REVISION"].presence || revision_file.presence || git_commit.presence || "unknown"
  end

  def git_describe
    git("describe", "--tags", "--always", "--dirty")
  end

  def git_commit
    git("rev-parse", "--short", "HEAD")
  end

  def warm_git_metadata
    git_describe
    git_commit
  end

  def revision_file
    path = Rails.root.join("REVISION")
    path.read.strip if path.exist?
  end

  def git(*args)
    @git ||= {}
    return @git[args] if @git.key?(args)

    @git[args] = IO.popen(["git", "-C", Rails.root.to_s, *args], err: File::NULL, &:read).strip.presence
  rescue SystemCallError
    nil
  end
end
