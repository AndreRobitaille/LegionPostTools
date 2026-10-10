require "uri"

class CalendarPdf
  GenerationError = BrowserPdfRenderer::GenerationError
  TOKEN_LIFETIME = 1.minute

  class << self
    def render(organization:, month:, base_url: nil)
      token = source_token(organization:, month:)
      port = ENV.fetch("PDF_RENDER_PORT", ENV.fetch("PORT", "3000"))
      base_url ||= "http://127.0.0.1:#{port}"
      source_url = "#{base_url.chomp("/")}/internal/calendar-pdf-source?#{URI.encode_www_form(token: token)}"
      BrowserPdfRenderer.render(source_url:, temp_prefix: "calendar-pdf")
    end

    def filename(month:)
      "calendar-#{month.date.strftime('%Y-%m')}-#{month.view}.pdf"
    end

    def source_token(organization:, month:)
      verifier.generate(
        {
          "organization_id" => organization.id,
          "date" => month.date.iso8601,
          "view" => month.view,
          "categories" => month.categories
        }, expires_in: TOKEN_LIFETIME
      )
    end

    def verify_source_token!(token)
      payload = verifier.verify(token)
      date = Date.iso8601(payload.fetch("date"))
      categories = payload.fetch("categories")
      unless (1900..2200).cover?(date.year) && date.day == 1 &&
          CalendarMonth::VIEWS.key?(payload.fetch("view")) &&
          categories.is_a?(Array) && (categories - CalendarCategories::LABELS.keys).empty?
        raise ArgumentError, "invalid calendar PDF selection"
      end
      payload
    end

    private

    def verifier
      Rails.application.message_verifier("calendar-pdf-source")
    end
  end
end
