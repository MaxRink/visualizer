# Rails reads Active Record encryption keys from credentials only
# (active_record/railtie.rb), but the deployment ships them as environment
# variables so they stay in the protected .env rather than in a committed
# credentials file. Map them across here; this initializer runs before
# upload_key_encryption.rb (alphabetical order), which asserts they are set.
%w[PRIMARY_KEY DETERMINISTIC_KEY KEY_DERIVATION_SALT].each do |name|
  value = ENV["ACTIVE_RECORD_ENCRYPTION_#{name}"]
  next if value.blank?

  attribute = name.downcase
  Rails.application.config.active_record.encryption.public_send("#{attribute}=", value)
end

ApiToken.ensure_encryption_configured! if defined?(ApiToken) && Rails.env.production?
