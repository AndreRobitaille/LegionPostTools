require "test_helper"

class Loops::ClientTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:body, :code, :headers) do
    def [](name)
      headers[name]
    end
  end

  FakeHttp = Struct.new(:responses, :requests) do
    def request(request)
      requests << request
      responses.shift
    end
  end

  test "updates a contact with an authenticated JSON put request" do
    response = json_response("200", success: true, id: "contact_1")
    http = FakeHttp.new([ response ], [])
    client = Loops::Client.new(api_key: "secret")
    client.instance_variable_set(:@http, http)

    result = client.update_contact(email: "member@example.com", firstName: "Ada")

    assert_equal "contact_1", result["id"]
    request = http.requests.first
    assert_instance_of Net::HTTP::Put, request
    assert_equal "Bearer secret", request["Authorization"]
    assert_equal({ "email" => "member@example.com", "firstName" => "Ada" }, JSON.parse(request.body))
  end

  test "retries a rate limited contact update after Retry-After" do
    limited = json_response("429", { success: false, message: "Slow down" }, "Retry-After" => "0.5")
    accepted = json_response("200", success: true, id: "contact_1")
    waits = []
    http = FakeHttp.new([ limited, accepted ], [])
    client = Loops::Client.new(api_key: "secret", sleeper: ->(seconds) { waits << seconds })
    client.instance_variable_set(:@http, http)

    client.update_contact(email: "member@example.com")

    assert_includes waits, 0.5
    assert_equal 2, http.requests.size
  end

  test "raises provider message for a rejected update" do
    response = json_response("400", success: false, message: "Invalid email")
    client = Loops::Client.new(api_key: "secret")
    client.instance_variable_set(:@http, FakeHttp.new([ response ], []))

    error = assert_raises(Loops::Client::RequestError) do
      client.update_contact(email: "bad")
    end

    assert_equal 400, error.status
    assert_equal "Invalid email", error.message
  end

  test "find and suppression use encoded read-only requests and validate unknown state" do
    responses = [
      json_response("200", [ { id: "outside-1", email: "outside+office@example.test", subscribed: true, mailingLists: { minutes: true } } ]),
      json_response("200", { isSuppressed: false, contact: { id: "outside-1" } }),
      json_response("200", { success: true })
    ]
    http = FakeHttp.new(responses, [])
    client = Loops::Client.new(api_key: "offline-key", sleeper: ->(_) { })
    client.instance_variable_set(:@http, http)
    assert_equal "outside-1", client.find_contact(email: "outside+office@example.test").fetch("id")
    assert_equal false, client.suppressed?(email: "outside+office@example.test")
    assert_raises(Loops::Client::RequestError) { client.suppressed?(email: "outside+office@example.test") }
    assert_instance_of Net::HTTP::Get, http.requests.first
    assert_includes http.requests.first.path, "email=outside%2Boffice%40example.test"
    assert http.requests.all? { |request| request["Authorization"] == "Bearer offline-key" }
  end

  test "transactional retry retains its key and only acknowledges the matching duplicate response" do
    response = json_response("409", success: false, message: "Request with idempotency key stable-key has already been processed.")
    wrong_key = json_response("409", success: false, message: "Request with idempotency key another-key has already been processed.")
    http = FakeHttp.new([ response, wrong_key ], [])
    client = Loops::Client.new(api_key: "offline-key", sleeper: ->(_) { })
    client.instance_variable_set(:@http, http)
    payload = { email: "outside@example.test", transactionalId: "template", addToAudience: false }
    assert_equal({ "success" => true }, client.send_transactional(payload, idempotency_key: "stable-key"))
    assert_raises(Loops::Client::RequestError) { client.send_transactional(payload, idempotency_key: "stable-key") }
    assert_equal [ "stable-key", "stable-key" ], http.requests.map { |request| request["Idempotency-Key"] }
    assert http.requests.all? { |request| request.is_a?(Net::HTTP::Post) && JSON.parse(request.body)["addToAudience"] == false }
  end

  test "a successful HTTP status with an unexpected send body is not email acceptance" do
    http = FakeHttp.new([ json_response("200", []), json_response("200", false) ], [])
    client = Loops::Client.new(api_key: "offline-key", sleeper: ->(_) { })
    client.instance_variable_set(:@http, http)
    2.times do
      assert_raises(Loops::Client::RequestError) do
        client.send_transactional({ email: "outside@example.test" }, idempotency_key: "unexpected-body")
      end
    end
  end

  private

  def json_response(code, body, headers = {})
    FakeResponse.new(JSON.generate(body), code, headers)
  end
end
