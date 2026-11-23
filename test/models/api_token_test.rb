require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "generates a prefixed token on create" do
    api_token = create(:api_token)

    assert api_token.token.start_with?(ApiToken::PREFIX)
    assert_operator api_token.token.length, :>, 40
  end

  test "finds only active tokens by value" do
    api_token = create(:api_token)

    assert_equal api_token, ApiToken.find_active_by_token(api_token.token)

    api_token.revoke!

    assert_nil ApiToken.find_active_by_token(api_token.token)
  end

  test "masks all but the token ends" do
    api_token = build(:api_token, token: "vzu_abcdefghijklmnopqrstuvwxyz0123")

    assert_equal "vzu_abcd************0123", api_token.masked_token
  end

  test "reports missing encryption settings" do
    assert_empty ApiToken.missing_encryption_settings

    config = Struct.new(:primary_key, :deterministic_key, :key_derivation_salt).new(nil, "deterministic", nil)

    assert_equal %w[primary_key key_derivation_salt], ApiToken.missing_encryption_settings(config)
  end

  test "raises with the missing setting names when encryption is unconfigured" do
    config = Struct.new(:primary_key, :deterministic_key, :key_derivation_salt).new(nil, nil, nil)

    error = assert_raises(RuntimeError) { ApiToken.ensure_encryption_configured!(config) }

    assert_includes error.message, "primary_key, deterministic_key, key_derivation_salt"
    assert_includes error.message, "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"
  end

  test "does not raise when encryption is configured" do
    assert_nil ApiToken.ensure_encryption_configured!
  end

  test "rotating keeps one active token per user" do
    user = create(:user)
    first = user.rotate_upload_key!

    second = user.rotate_upload_key!

    assert first.reload.revoked?
    assert_not second.revoked?
    assert_equal [second], user.api_tokens.active.to_a
  end
end
