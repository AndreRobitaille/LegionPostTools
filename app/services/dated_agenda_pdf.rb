require "tmpdir"
require "timeout"
require "uri"

class DatedAgendaPdf
  class GenerationError < StandardError; end

  VARIANTS = %w[agenda officer_notes].freeze
  TOKEN_LIFETIME = 1.minute
  RENDER_TIMEOUT = 30.seconds

  class << self
    def render(dated_agenda:, variant:, base_url: nil)
      new(dated_agenda:, variant:, base_url:).render
    end

    def filename(dated_agenda:, variant:)
      validate_variant!(variant)
      document_kind = variant == "officer_notes" ? "officer-notes" : "agenda"
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
    Dir.mktmpdir("dated-agenda-pdf") do |directory|
      pdf_path = File.join(directory, "document.pdf")
      process_id = Process.spawn(*chromium_command(pdf_path), out: File::NULL, err: File::NULL, pgroup: true)
      status = wait_for_renderer(process_id)

      raise GenerationError, "PDF renderer failed" unless status.success? && File.exist?(pdf_path)

      pdf = File.binread(pdf_path)
      raise GenerationError, "PDF renderer returned an invalid document" unless pdf.start_with?("%PDF")

      pdf
    end
  rescue Errno::ENOENT
    raise GenerationError, "PDF renderer is unavailable"
  end

  private

  def chromium_command(pdf_path)
    [
      ENV.fetch("CHROMIUM_BIN", "/usr/bin/chromium"),
      "--headless=new",
      "--disable-gpu",
      "--disable-dev-shm-usage",
      "--disable-extensions",
      "--no-sandbox",
      "--no-pdf-header-footer",
      "--run-all-compositor-stages-before-draw",
      "--virtual-time-budget=3000",
      "--print-to-pdf=#{pdf_path}",
      source_url
    ]
  end

  def source_url
    token = self.class.source_token(dated_agenda: @dated_agenda, variant: @variant)
    query = URI.encode_www_form(token: token)
    "#{@base_url.chomp("/")}/internal/dated-agenda-pdf-source?#{query}"
  end

  def default_base_url
    port = ENV.fetch("PDF_RENDER_PORT", ENV.fetch("PORT", "3000"))
    "http://127.0.0.1:#{port}"
  end

  def wait_for_renderer(process_id)
    Timeout.timeout(RENDER_TIMEOUT) do
      Process.wait2(process_id).last
    end
  rescue Timeout::Error
    terminate_renderer(process_id)
    raise GenerationError, "PDF renderer timed out"
  end

  def terminate_renderer(process_id)
    Process.kill("TERM", -process_id)
    Timeout.timeout(2.seconds) { Process.wait(process_id) }
  rescue Timeout::Error
    Process.kill("KILL", -process_id)
    Process.wait(process_id)
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  end
end
