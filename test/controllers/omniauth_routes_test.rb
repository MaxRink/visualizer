require "test_helper"

class OmniauthRoutesTest < ActionDispatch::IntegrationTest
  setup do
    host! "example.com"
    @previous_test_mode = OmniAuth.config.test_mode
    @previous_oidc = %w[OIDC_ISSUER OIDC_CLIENT_ID OIDC_CLIENT_SECRET].index_with { |key| ENV[key] }
    %w[OIDC_ISSUER OIDC_CLIENT_ID OIDC_CLIENT_SECRET].each { |key| ENV.delete(key) }
    OmniAuth.config.test_mode = false
  end

  teardown do
    OmniAuth.config.test_mode = @previous_test_mode
    OmniAuth.config.mock_auth[:airtable] = nil
    @previous_oidc.each { |key, value| ENV[key] = value }
  end

  test "unconfigured Airtable GET is not found, not a 500" do
    stubbing(AirtableConfig, :configured?, false) do
      get connect_airtable_path
    end

    assert_response :not_found
  end

  test "configured Airtable GET only allows POST" do
    stubbing(AirtableConfig, :configured?, true) do
      get connect_airtable_path
    end

    assert_response :method_not_allowed
    assert_equal "POST", response.headers["Allow"]
  end

  test "configured Airtable POST is handled by the provider" do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:airtable] = OmniAuth::AuthHash.new(provider: "airtable", uid: "uid")

    stubbing(AirtableConfig, :configured?, true) do
      post "/auth/airtable"
    end

    assert_response :redirect
    assert_match(%r{/auth/airtable/callback}, response.location)
  end

  test "unconfigured OIDC POST is not found, not a 500" do
    post sign_in_with_homelab_oidc_path

    assert_response :not_found
  end

  private

  def stubbing(receiver, method_name, value)
    original = receiver.method(method_name)
    receiver.define_singleton_method(method_name) { value }
    yield
  ensure
    receiver.define_singleton_method(method_name, original)
  end
end
