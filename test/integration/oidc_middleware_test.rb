require "test_helper"
require "rack/test"
require "json/jwt"
require "openssl"

class OidcMiddlewareTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  ISSUER = "https://issuer.example.test"
  AUTHORIZATION_ENDPOINT = "https://issuer.example.test/authorize"
  TOKEN_ENDPOINT = "https://issuer.example.test/token"
  JWKS_URI = "https://issuer.example.test/jwks"

  setup do
    @signing_key = OpenSSL::PKey::RSA.generate(2048)
    @jwk = JSON::JWK.new(@signing_key.public_key).merge("kid" => "test-key")
    OmniAuth.config.allowed_request_methods = %i[post]
    stub_request(:get, "#{ISSUER}/.well-known/openid-configuration").to_return(
      status: 200,
      body: {
        issuer: ISSUER,
        authorization_endpoint: AUTHORIZATION_ENDPOINT,
        token_endpoint: TOKEN_ENDPOINT,
        jwks_uri: JWKS_URI,
        userinfo_endpoint: "https://issuer.example.test/userinfo",
        response_types_supported: ["code"],
        subject_types_supported: ["public"],
        id_token_signing_alg_values_supported: ["RS256"]
      }.to_json,
      headers: {"Content-Type" => "application/json"}
    )
    stub_request(:get, JWKS_URI).to_return(
      status: 200,
      body: {keys: [@jwk]}.to_json,
      headers: {"Content-Type" => "application/json"}
    )
    stub_request(:get, "https://issuer.example.test/userinfo").to_return(
      status: 200,
      body: {sub: "subject-1", email: "user@example.test", email_verified: true}.to_json,
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

  test "accepts a valid signed ID token with the requested nonce" do
    post "/auth/test_oidc"
    query = URI.decode_www_form(URI(last_response["location"]).query).to_h
    stub_token_response(query.fetch("nonce"))

    get "/auth/test_oidc/callback", code: "authorization-code", state: query.fetch("state")

    assert_equal 200, last_response.status
    assert_includes last_response.body, "subject-1"
  end

  test "rejects a validly signed token with the wrong nonce" do
    post "/auth/test_oidc"
    query = URI.decode_www_form(URI(last_response["location"]).query).to_h
    stub_token_response("wrong-nonce")

    get "/auth/test_oidc/callback", code: "authorization-code", state: query.fetch("state")

    assert_equal 302, last_response.status
  end

  test "rejects a token signed by an unknown key" do
    post "/auth/test_oidc"
    query = URI.decode_www_form(URI(last_response["location"]).query).to_h
    unknown_key = OpenSSL::PKey::RSA.generate(2048)
    stub_token_response(query.fetch("nonce"), signing_key: unknown_key)

    get "/auth/test_oidc/callback", code: "authorization-code", state: query.fetch("state")

    assert_equal 302, last_response.status
  end

  test "rejects a token with a different issuer" do
    post "/auth/test_oidc"
    query = URI.decode_www_form(URI(last_response["location"]).query).to_h
    stub_token_response(query.fetch("nonce"), issuer: "https://evil.example.test")

    get "/auth/test_oidc/callback", code: "authorization-code", state: query.fetch("state")

    assert_equal 302, last_response.status
  end

  private

  def stub_token_response(nonce, signing_key: @signing_key, issuer: ISSUER)
    claims = {
      iss: issuer,
      sub: "subject-1",
      aud: "test-client",
      nonce: nonce,
      iat: Time.now.to_i,
      exp: 5.minutes.from_now.to_i,
      email: "user@example.test",
      email_verified: true
    }
    id_token = JSON::JWT.new(claims).sign(JSON::JWK.new(signing_key).merge("kid" => "test-key"), :RS256).to_s
    stub_request(:post, TOKEN_ENDPOINT).to_return(
      status: 200,
      body: {access_token: "access-token", token_type: "Bearer", id_token: id_token}.to_json,
      headers: {"Content-Type" => "application/json"}
    )
  end

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
