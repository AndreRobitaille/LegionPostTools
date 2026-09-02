require "uri"

class MeetingMinutesPdf
  GenerationError = BrowserPdfRenderer::GenerationError

  TOKEN_LIFETIME = 1.minute

  class << self
    def render(minutes:, base_url: nil)
      new(minutes:, base_url:).render
    end

    def filename(minutes:)
      meeting_name = minutes.meeting_type&.slug.presence ||
        minutes.meeting_type&.name&.parameterize.presence ||
        minutes.meeting_body.name.parameterize

      document_suffix = {
        "draft" => "draft-minutes",
        "approved" => "approved-minutes",
        "attested" => "attested-minutes",
        "membership_approved" => "official-minutes"
      }.fetch(minutes.status)

      "#{meeting_name}-#{minutes.starts_at.to_date.iso8601}-#{document_suffix}.pdf"
    end

    def source_token(minutes:)
      verifier.generate(
        {
          "organization_id" => minutes.organization_id,
          "meeting_minutes_id" => minutes.id
        },
        expires_in: TOKEN_LIFETIME
      )
    end

    def verify_source_token!(token)
      verifier.verify(token)
    end

    private

    def verifier
      Rails.application.message_verifier("meeting-minutes-pdf-source")
    end
  end

  def initialize(minutes:, base_url: nil)
    @minutes = minutes
    @base_url = base_url || default_base_url
  end

  def render
    BrowserPdfRenderer.render(source_url:, temp_prefix: "meeting-minutes-pdf")
  end

  private

  def source_url
    query = URI.encode_www_form(token: self.class.source_token(minutes: @minutes))
    "#{@base_url.chomp("/")}/internal/meeting-minutes-pdf-source?#{query}"
  end

  def default_base_url
    port = ENV.fetch("PDF_RENDER_PORT", ENV.fetch("PORT", "3000"))
    "http://127.0.0.1:#{port}"
  end
end
