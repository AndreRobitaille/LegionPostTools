require "uri"

class DatedAgendaPdf
  GenerationError = BrowserPdfRenderer::GenerationError

  VARIANTS = %w[agenda officer_notes].freeze
  TOKEN_LIFETIME = 1.minute

  class << self
    def render(dated_agenda:, variant:, base_url: nil)
      new(dated_agenda:, variant:, base_url:).render
    end

    def filename(dated_agenda:, variant:)
      validate_variant!(variant)
      document_kind = variant == "officer_notes" ? "commander-adjutant-notes" : "agenda"
      meeting_name = dated_agenda.meeting_type.slug.presence || dated_agenda.meeting_type.name.parameterize

      "#{meeting_name}-#{dated_agenda.starts_at.to_date.iso8601}-#{document_kind}.pdf"
    end

    def source_token(dated_agenda:, variant:)
      validate_variant!(variant)
      verifier.generate(
        {
          "organization_id" => dated_agenda.organization_id,
          "dated_agenda_id" => dated_agenda.id,
          "variant" => variant
        },
        expires_in: TOKEN_LIFETIME
      )
    end

    def verify_source_token!(token)
      payload = verifier.verify(token)
      validate_variant!(payload.fetch("variant"))
      payload
    end

    def validate_variant!(variant)
      return if variant.in?(VARIANTS)

      raise ArgumentError, "unknown agenda PDF variant"
    end

    private

    def verifier
      Rails.application.message_verifier("dated-agenda-pdf-source")
    end
  end

  def initialize(dated_agenda:, variant:, base_url: nil)
    self.class.validate_variant!(variant)
    @dated_agenda = dated_agenda
    @variant = variant
    @base_url = base_url || default_base_url
  end

  def render
    BrowserPdfRenderer.render(source_url:, temp_prefix: "dated-agenda-pdf")
  end

  private

  def source_url
    token = self.class.source_token(dated_agenda: @dated_agenda, variant: @variant)
    query = URI.encode_www_form(token: token)
    "#{@base_url.chomp("/")}/internal/dated-agenda-pdf-source?#{query}"
  end

  def default_base_url
    port = ENV.fetch("PDF_RENDER_PORT", ENV.fetch("PORT", "3000"))
    "http://127.0.0.1:#{port}"
  end
end
