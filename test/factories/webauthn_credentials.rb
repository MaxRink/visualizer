FactoryBot.define do
  factory :webauthn_credential do
    user
    sequence(:external_id) { "credential-#{it}" }
    public_key { SecureRandom.base64(32) }
    nickname { "Laptop passkey" }
    sign_count { 0 }
  end
end
