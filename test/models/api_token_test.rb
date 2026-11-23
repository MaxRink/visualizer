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

  test "rotating keeps one active token per user" do
    user = create(:user)
    first = user.rotate_upload_key!

    second = user.rotate_upload_key!

    assert first.reload.revoked?
    assert_not second.revoked?
    assert_equal [second], user.api_tokens.active.to_a
  end
end
