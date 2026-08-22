require "net/http"

module MailDelivery
  # Sends the magic link through Loops.so's transactional API. The message body
  # is rendered by a Loops template (configured in the Loops dashboard); the
  # login URL is passed as a data variable. Swappable via MAIL_PROVIDER.
  class LoopsBackend
    ENDPOINT = URI("https://app.loops.so/api/v1/transactional").freeze

    def deliver_magic_link(user:, login_url:, login_code:)
      post(
        transactionalId: ENV.fetch("LOOPS_MAGIC_LINK_TEMPLATE_ID"),
        email: user.email_address,
        dataVariables: { login_url: login_url, login_code: login_code, name: user.person.full_name }
      )
    end
    private

    def post(payload)
      http = Net::HTTP.new(ENDPOINT.host, ENDPOINT.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 10
      request = Net::HTTP::Post.new(ENDPOINT)
      request["Authorization"] = "Bearer #{ENV.fetch('LOOPS_API_KEY')}"
      request["Content-Type"] = "application/json"
      request["Idempotency-Key"] = SecureRandom.uuid
      request.body = JSON.generate(payload)
      response = http.request(request)
      validate_response!(response)
      Rails.logger.info("Loops transactional email accepted template_id=#{payload[:transactionalId]} status=#{response.code}")
      true
    rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError => error
      raise DeliveryError.new("Loops request failed (#{error.class.name}).")
    end

    def validate_response!(response)
      body = JSON.parse(response.body)
      return body if response.is_a?(Net::HTTPSuccess) && body["success"] == true

      message = body["message"].presence || "Loops rejected the transactional email."
      raise DeliveryError.new(message, status: response.code.to_i)
    rescue JSON::ParserError
      raise DeliveryError.new("Loops returned an unreadable response.", status: response.code.to_i)
    end
  end
end
