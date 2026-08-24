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

    assert_equal [ 0.5 ], waits
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

  private

  def json_response(code, body, headers = {})
    FakeResponse.new(JSON.generate(body), code, headers)
  end
end
