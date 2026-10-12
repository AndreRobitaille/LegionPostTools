require "net/http"
require "nokogiri"

# Real HTTPS requests to the running process, with normal certificate verification.
# This protocol probe supplies Origin explicitly; it does not test browser headers.
# Credentials stay in memory; output contains only evidence labels and opaque IDs.
class BuddyMobileProbe
  attr_reader :token

  def initialize
    @origin = URI(ENV.fetch("MOBILE_BUDDY_CHECK_ISSUER"))
    @cookies = {}
  end

  def assert(condition, message)
    raise message unless condition
  end

  def request(method, path, form: nil, json: nil, authenticated: false)
    uri = URI.join(@origin.to_s, path)
    assert(uri.scheme == "https" && uri.host == @origin.host && uri.port == @origin.port, "Refusing a different origin")
    http = Net::HTTP.new(uri.host, uri.port, nil)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.ca_file = File.join(File.dirname(ENV.fetch("BUDDY_MOBILE_TLS_CERT")), "ca.pem")
    http.open_timeout = 5
    http.read_timeout = 15
    request = Net::HTTP.const_get(method.capitalize).new(uri)
    request["Cookie"] = @cookies.map { |key, value| "#{key}=#{value}" }.join("; ")
    request["Origin"] = @origin.to_s
    request["Authorization"] = "Bearer #{@token}" if authenticated
    request.set_form_data(form) if form
    if json
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(json)
    end
    response = http.request(request)
    Array(response.get_fields("set-cookie")).each do |cookie|
      key, value = cookie.split(";", 2).first.split("=", 2)
      @cookies[key] = value
      assert(cookie.match?(/;\s*secure(?:;|$)/i), "Browser cookie lacked Secure")
    end
    response
  end

  def csrf(response, action)
    Nokogiri::HTML(response.body).at_css("form[action='#{action}'] input[name='authenticity_token']")["value"]
  end

  def sign_in(user, use_code: false)
    verifier = SecureRandom.urlsafe_base64(48)
    authorization = { client_id: ENV.fetch("MOBILE_BUDDY_CHECK_CLIENT_ID"), response_type: "code", scope: "buddy_check",
      redirect_uri: ENV.fetch("MOBILE_BUDDY_CHECK_REDIRECT_URI"), state: SecureRandom.hex(32), code_challenge_method: "S256",
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false) }
    response = request("get", "/oauth/authorize?#{authorization.to_query}")
    assert(response.code == "302", "Authorization did not require human sign-in")
    if use_code
      form = request("get", response.fetch("location"))
      pending = request("post", "/session", form: { email_address: user.email_address, authenticity_token: csrf(form, "/session") })
      assert(pending.code == "302", "Email-code request failed")
      inbox_path = File.join(File.dirname(ENV.fetch("BUDDY_MOBILE_FIXTURE_FILE")), "mail", "#{user.id}.json")
      inbox = JSON.parse(File.read(inbox_path))
      assert(inbox.fetch("email") == user.email_address && Time.iso8601(inbox.fetch("expires_at")) > Time.current, "Synthetic inbox mismatch")
      form = request("get", pending.fetch("location"))
      denied = request("post", "/session/code", form: { code: inbox.fetch("login_code") })
      assert(denied.code == "422", "Code sign-in without CSRF was not rejected")
      signed_in = request("post", "/session/code", form: { code: inbox.fetch("login_code"), authenticity_token: csrf(form, "/session/code") })
    else
      link = MagicLink.create_for!(user)
      form = request("get", "/session/magic_link?#{ { token: link.token }.to_query }")
      denied = request("post", "/session/magic_link", form: { token: link.token })
      assert(denied.code == "422", "Sign-in without CSRF was not rejected")
      signed_in = request("post", "/session/magic_link", form: { token: link.token, authenticity_token: csrf(form, "/session/magic_link") })
    end
    assert(signed_in.code == "302", "Human sign-in failed")
    consent = request("get", signed_in.fetch("location"))
    assert(consent.code == "200" && consent.body.include?("Connect Buddy Checks"), "Sign-in did not return to consent")
    assert(consent["referrer-policy"] == "strict-origin", "Consent referrer policy changed")
    assert(consent["cache-control"] == "no-store", "Consent was cacheable")
    callback = request("post", "/oauth/authorize", form: authorization.merge(authenticity_token: csrf(consent, "/oauth/authorize")))
    assert(callback.code == "302", "Consent did not issue a callback (HTTP #{callback.code})")
    callback_uri = URI(callback.fetch("location"))
    assert(callback_uri.to_s.split("?").first == authorization[:redirect_uri], "Callback changed")
    returned = URI.decode_www_form(callback_uri.query).to_h
    assert(returned.fetch("state") == authorization[:state], "Callback state changed")
    exchange = { client_id: authorization[:client_id], redirect_uri: authorization[:redirect_uri], grant_type: "authorization_code",
      code: returned.fetch("code"), code_verifier: verifier }
    assert(request("post", "/oauth/token", form: exchange.merge(code_verifier: "x" * 64)).code == "400", "Wrong PKCE verifier accepted")
    response = request("post", "/oauth/token", form: exchange)
    assert(response.code == "200", "Code exchange failed")
    payload = JSON.parse(response.body)
    @token = payload.fetch("access_token")
    assert(payload.fetch("expires_in") == 900 && payload["refresh_token"].nil?, "Unexpected credential lifetime")
    assert(request("post", "/oauth/token", form: exchange).code == "400", "Code replay accepted")
    puts "PASS: HTTPS human sign-in, CSRF, secure cookies, exact callback/state, S256, code replay (user #{user.id})"
  end

  def api(method, path, status: 200, body: nil)
    response = request(method, "/api/mobile/v1#{path}", json: body, authenticated: true)
    assert(response.code.to_i == status, "Unexpected HTTP #{response.code} for #{method} #{path}; expected #{status}")
    assert(response["cache-control"].include?("no-store"), "Private response was cacheable")
    JSON.parse(response.body)
  end
end
