require "test_helper"
require "rack/test"

class OidcMiddlewareTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  ISSUER = "https://issuer.example.test"
  AUTHORIZATION_ENDPOINT = "https://issuer.example.test/authorize"
  TOKEN_ENDPOINT = "https://issuer.example.test/token"
  JWKS_URI = "https://issuer.example.test/jwks"

  setup do
    OmniAuth.config.allowed_request_methods = %i[post]
    stub_request(:get, "#{ISSUER}/.well-known/openid-configuration").to_return(
      status: 200,
      body: {
        issuer: ISSUER,
        authorization_endpoint: AUTHORIZATION_ENDPOINT,
        token_endpoint: TOKEN_ENDPOINT,
        jwks_uri: JWKS_URI
      }.to_json,
      headers: {"Content-Type" => "application/json"}
    )
  end

  test "rejects a replayed state before exchanging the authorization code" do
    post "/auth/test_oidc"
    assert_equal 302, last_response.status

    get "/auth/test_oidc/callback", code: "replayed-code", state: "replayed-state"

    assert_equal 302, last_response.status
    assert_not_requested :post, TOKEN_ENDPOINT
  end

  test "rejects a malformed ID token after the code exchange" do
    post "/auth/test_oidc"
    state = URI.decode_www_form(URI(last_response["location"]).query).to_h.fetch("state")
    stub_request(:post, TOKEN_ENDPOINT).to_return(
      status: 200,
      body: {access_token: "access-token", token_type: "Bearer", id_token: "not-a-jwt"}.to_json,
      headers: {"Content-Type" => "application/json"}
    )

    get "/auth/test_oidc/callback", code: "authorization-code", state: state

    assert_equal 302, last_response.status
    assert_requested :post, TOKEN_ENDPOINT
  end

  private

  def app
    @app ||= Rack::Builder.new do
      use Rack::Session::Cookie, secret: "oidc-middleware-test-secret-#{'x' * 40}"
      use OmniAuth::Builder do
        provider(
          :openid_connect,
          name: :test_oidc,
          scope: %i[openid profile email],
          response_type: :code,
          issuer: OidcMiddlewareTest::ISSUER,
          discovery: true,
          client_options: {
            identifier: "test-client",
            secret: "test-secret",
            redirect_uri: "https://app.example.test/auth/test_oidc/callback"
          }
        )
      end
      run ->(env) { [200, {"content-type" => "text/plain"}, [env["omniauth.auth"].to_s]] }
    end.to_app
  end
end
