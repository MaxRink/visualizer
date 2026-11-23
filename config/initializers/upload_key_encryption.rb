# Upload keys are stored with Active Record encryption (see ApiToken). Without
# keys the first token write fails inside a request instead of at deploy time,
# so production refuses to boot with a message that names what is missing.
Rails.application.config.after_initialize do
  next unless Rails.env.production?
  # The Dockerfile precompiles assets with SECRET_KEY_BASE_DUMMY and no
  # runtime secrets, so these guards must not fire at image build time.
  next if ENV["SECRET_KEY_BASE_DUMMY"].present?

  # Keys come from ACTIVE_RECORD_ENCRYPTION_* via
  # active_record_encryption_env.rb, which runs before this initializer's
  # after_initialize block.
  ApiToken.ensure_encryption_configured!
end
