require "net/http"

module MailDelivery
  # Sends the magic link through Loops.so's transactional API. The message body
  # is rendered by a Loops template (configured in the Loops dashboard); the
  # login URL is passed as a data variable. Swappable via MAIL_PROVIDER.
  class LoopsBackend
    ENDPOINT = URI("https://app.loops.so/api/v1/transactional").freeze

    def deliver_magic_link(user:, login_url:)
      post(
        transactionalId: ENV.fetch("LOOPS_MAGIC_LINK_TEMPLATE_ID"),
        email: user.email_address,
        dataVariables: { login_url: login_url, name: user.person.full_name }
      )
    end

    private

    def post(payload)
      http = Net::HTTP.new(ENDPOINT.host, ENDPOINT.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(ENDPOINT)
      request["Authorization"] = "Bearer #{ENV.fetch('LOOPS_API_KEY')}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)
      http.request(request)
    end
  end
end
