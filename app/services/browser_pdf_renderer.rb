require "tmpdir"
require "timeout"

class BrowserPdfRenderer
  class GenerationError < StandardError; end

  RENDER_TIMEOUT = 30.seconds

  class << self
    def render(source_url:, temp_prefix:)
      new(source_url:, temp_prefix:).render
    end
  end

  def initialize(source_url:, temp_prefix:)
    @source_url = source_url
    @temp_prefix = temp_prefix
  end

  def render
    Dir.mktmpdir(@temp_prefix) do |directory|
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
      "--user-data-dir=#{File.join(File.dirname(pdf_path), "chromium-profile")}",
      "--run-all-compositor-stages-before-draw",
      "--virtual-time-budget=3000",
      "--print-to-pdf=#{pdf_path}",
      @source_url
    ]
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
