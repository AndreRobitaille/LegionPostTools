require "uri"

class MembershipPdf
  GenerationError = BrowserPdfRenderer::GenerationError
  TOKEN_LIFETIME = 1.minute

  class << self
    def render(organization:, user:, drive: nil, summary: nil, caller_id: nil, base_url: nil)
      token = source_token(organization:, user:, drive:, summary:, caller_id:)
      port = ENV.fetch("PDF_RENDER_PORT", ENV.fetch("PORT", "3000"))
      base_url ||= "http://127.0.0.1:#{port}"
      source_url = "#{base_url.chomp('/')}/internal/membership-pdf-source?#{URI.encode_www_form(token:)}"
      BrowserPdfRenderer.render(source_url:, temp_prefix: "membership-pdf")
    end

    def source_token(organization:, user:, drive: nil, summary: nil, caller_id: nil)
      access = MembershipAccess.new(user:, organization:)
      if drive
        access.drives.find(drive.id)
      elsif summary && access.manager?
        organization.membership_summaries.find(summary.id)
      else
        raise MembershipWorkspace::AccessDenied, "This PDF needs current membership authority."
      end
      verifier.generate({ "organization_id" => organization.id, "user_id" => user.id,
        "drive_id" => drive&.id, "summary_id" => summary&.id,
        "caller_id" => access.manager? ? caller_id.presence : user.id,
        "packet_id" => SecureRandom.hex(6) }, expires_in: TOKEN_LIFETIME)
    end

    def verify_source_token!(token)
      verifier.verify(token)
    end

    private

    def verifier
      Rails.application.message_verifier("membership-pdf-source")
    end
  end
end
