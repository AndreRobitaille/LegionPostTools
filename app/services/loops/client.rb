require "net/http"

module Loops
  class Client
    ENDPOINT = URI("https://app.loops.so/api/v1/contacts/update").freeze
    MAX_RATE_LIMIT_RETRIES = 2

    class RequestError < StandardError
      attr_reader :status

      def initialize(message, status: nil)
        @status = status
        super(message)
      end
    end

    class NetworkError < StandardError; end

    def self.configured?
      ENV["LOOPS_API_KEY"].present?
    end

    def initialize(api_key: ENV.fetch("LOOPS_API_KEY"), sleeper: ->(seconds) { sleep(seconds) })
      @api_key = api_key
      @sleeper = sleeper
    end

    def open
      http = Net::HTTP.new(ENDPOINT.host, ENDPOINT.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 10

      http.start do
        @http = http
        yield self
      ensure
        @http = nil
      end
    rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError => error
      raise NetworkError, "Loops connection failed (#{error.class.name})."
    end

    def update_contact(payload)
      raise "Open a Loops client session before updating contacts." unless @http

      attempts = 0
      loop do
        response = @http.request(build_request(payload))
        if response.code.to_i == 429 && attempts < MAX_RATE_LIMIT_RETRIES
          attempts += 1
          @sleeper.call(retry_after(response))
          next
        end

        return validate_response!(response)
      end
    rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError => error
      raise NetworkError, "Loops request failed (#{error.class.name})."
    end

    private

    def build_request(payload)
      request = Net::HTTP::Put.new(ENDPOINT)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)
      request
    end

    def validate_response!(response)
      body = JSON.parse(response.body)
      return body if response.code.to_i.between?(200, 299) && body["success"] == true

      message = body["message"].presence || "Loops rejected the contact update."
      raise RequestError.new(message, status: response.code.to_i)
    rescue JSON::ParserError
      raise RequestError.new("Loops returned an unreadable response.", status: response.code.to_i)
    end

    def retry_after(response)
      seconds = Float(response["Retry-After"], exception: false) || 1.0
      seconds.clamp(0.1, 30.0)
    end
  end
end
