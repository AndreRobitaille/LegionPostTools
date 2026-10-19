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
    rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError, IOError => error
      raise NetworkError, "Loops connection failed (#{error.class.name})."
    end

    def update_contact(payload)
      request_json(:put, "contacts/update", payload: payload)
    end

    def find_contact(email: nil, user_id: nil)
      query = email ? { email: email } : { userId: user_id }
      contacts = request_json(:get, "contacts/find", query: query)
      unless contacts.is_a?(Array) && contacts.size <= 1 &&
          (contacts.empty? || (contacts.first.is_a?(Hash) && contacts.first["id"].present? &&
            contacts.first["email"].present? && contacts.first["mailingLists"].is_a?(Hash)))
        raise RequestError, "Loops contact identity or subscriptions are unreadable or ambiguous."
      end
      contacts.first
    end

    def mailing_lists
      result = request_json(:get, "lists")
      raise RequestError, "Loops returned unreadable mailing lists." unless result.is_a?(Array)
      result
    end

    def suppressed?(email:)
      result = request_json(:get, "contacts/suppression", query: { email: email })
      unless result.is_a?(Hash) && [ true, false ].include?(result["isSuppressed"])
        raise RequestError, "Loops suppression status is unknown."
      end
      result.fetch("isSuppressed")
    end

    def send_transactional(payload, idempotency_key:)
      request_json(:post, "transactional", payload: payload, idempotency_key: idempotency_key)
    end

    private

    def request_json(method, path, payload: nil, query: nil, idempotency_key: nil)
      raise "Open a Loops client session before updating contacts." unless @http

      attempts = 0
      loop do
        if @last_request_at
          remaining = 0.12 - (Process.clock_gettime(Process::CLOCK_MONOTONIC) - @last_request_at)
          @sleeper.call(remaining) if remaining.positive?
        end
        @last_request_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        response = @http.request(build_request(method, path, payload, query, idempotency_key))
        if response.code.to_i == 429 && attempts < MAX_RATE_LIMIT_RETRIES
          attempts += 1
          @sleeper.call(retry_after(response))
          next
        end

        # Only this dedicated endpoint/key uses a 409 as acknowledgement.
        if method == :post && path == "transactional" && duplicate_acknowledgement?(response, idempotency_key)
          return { "success" => true }
        end
        return validate_response!(response,
          array_response: method == :get && path.in?(%w[contacts/find lists]),
          suppression_response: method == :get && path == "contacts/suppression")
      end
    rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError, IOError => error
      raise NetworkError, "Loops request failed (#{error.class.name})."
    end

    def build_request(method, path, payload, query, idempotency_key)
      uri = URI("https://app.loops.so/api/v1/#{path}")
      uri.query = URI.encode_www_form(query) if query
      request = { get: Net::HTTP::Get, put: Net::HTTP::Put, post: Net::HTTP::Post }.fetch(method).new(uri)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"] = "application/json"
      request["Idempotency-Key"] = idempotency_key if idempotency_key
      request.body = JSON.generate(payload) if payload
      request
    end

    def validate_response!(response, array_response:, suppression_response:)
      body = JSON.parse(response.body)
      accepted = if array_response
        body.is_a?(Array)
      elsif suppression_response
        body.is_a?(Hash) && body.key?("isSuppressed")
      else
        body.is_a?(Hash) && body["success"] == true
      end
      return body if response.code.to_i.between?(200, 299) && accepted

      message = body.is_a?(Hash) && body["message"].presence
      message ||= "Loops returned an unsuccessful or unreadable response."
      raise RequestError.new(message, status: response.code.to_i)
    rescue JSON::ParserError
      raise RequestError.new("Loops returned an unreadable response.", status: response.code.to_i)
    end

    def duplicate_acknowledgement?(response, key)
      return false unless response.code.to_i == 409

      body = JSON.parse(response.body)
      body.is_a?(Hash) && body["success"] == false &&
        body["message"] == "Request with idempotency key #{key} has already been processed."
    rescue JSON::ParserError
      false
    end

    def retry_after(response)
      seconds = Float(response["Retry-After"], exception: false) || 1.0
      seconds.clamp(0.1, 30.0)
    end
  end
end
