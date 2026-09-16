require "application_system_test_case"
require "socket"
require "net/http"

class PdfResourceSecurityTest < ApplicationSystemTestCase
  setup do
    @original_app = Capybara.app
    Capybara.app = ActionDispatch::AssumeSSL.new(@original_app)
    @requests = Queue.new
    @trap = TCPServer.new("0.0.0.0", 0)
    @trap_url = "http://127.0.0.1:#{@trap.addr[1]}"
    @listener = Thread.new do
      loop do
        socket = @trap.accept
        @requests << socket.gets.to_s
        while (header = socket.gets) && header != "\r\n"
        end
        socket.write("HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
      ensure
        socket&.close
      end
    end
    @listener.report_on_exception = false
    assert_equal "", Net::HTTP.get(URI("#{@trap_url}/control"))
    assert_includes @requests.pop, "/control"

    @organization = Organization.create!(name: "Example Legion Post", unit_type: "american_legion_post",
      locality: "Wisconsin", mailing_address: "P.O. Box 11\nExample, WI", public_email: "post@example.test", timezone: "America/Chicago")
    body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    type = @organization.meeting_types.create!(name: "Membership Meeting", slug: "membership-meeting", position: 1, active: true)
    @agenda = create_dated_agenda!(organization: @organization, meeting_body: body, meeting_type: type,
      starts_at: Time.zone.local(2026, 9, 15, 19), title: "September Membership Meeting", status: "draft")
    @agenda.dated_agenda_items.create!(position: 1, title: "Community report", behavior_type: "report_slot", active: true,
      body: "<p>Service report for the membership.</p><ul><li>Food pantry collection</li><li>Veteran visits</li></ul><img src='#{@trap_url}/image' alt='Service chart'>",
      commander_notes: "<p>Call for the committee report.</p><video poster='#{@trap_url}/poster' src='#{@trap_url}/video'></video>")
    @minutes = MeetingMinutes.create_from_meeting!(meeting: @agenda.meeting)
    @minutes.sections.first.items.first.update!(
      body: "<p>The report was received.</p><img src='#{@trap_url}/minutes' alt='Service chart'>")
  end

  teardown do
    Capybara.app = @original_app
    @listener&.kill
    @listener&.join
    @trap&.close
  end

  test "PDF sources preserve document design and block resources before any request" do
    visit dated_agenda_pdf_source_path(token: DatedAgendaPdf.source_token(dated_agenda: @agenda, variant: "agenda"))
    assert_selector ".pdf-omitted-media", text: "Image omitted from PDF: Service chart"
    assert page.evaluate_script("document.querySelector('.agenda-emblem').naturalWidth > 0")
    assert_equal "grid", page.evaluate_script("getComputedStyle(document.querySelector('.agenda-letterhead')).display")
    assert_not page.evaluate_script("document.documentElement.scrollWidth > innerWidth")
    capture("agenda-desktop")
    page.current_window.resize_to(390, 844)
    assert_not page.evaluate_script("document.documentElement.scrollWidth > innerWidth")
    assert_operator page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('.pdf-omitted-media')).fontSize)"), :>=, 14
    capture("agenda-phone")

    # Deliberately bypass presentation sanitization: the HTTP policy must still stop
    # images, CSS, media, frames, connections and unrelated same-origin paths.
    blocked = page.evaluate_async_script(<<~JS, @trap_url)
      const origin = arguments[0], done = arguments[arguments.length - 1];
      window.blockedResources = [];
      document.addEventListener('securitypolicyviolation', e => window.blockedResources.push(e.blockedURI));
      const urls = [origin + '/image', origin + '/redirect', location.origin + '/up?pdf-probe=1',
        location.origin + '/internal/meeting-minutes-pdf-source?token=forbidden'];
      const loads = urls.map(url => new Promise(resolve => {
        const image = new Image(); image.onload = image.onerror = resolve; image.src = url; document.body.append(image);
      }));
      const video = document.createElement('video'); video.poster = origin + '/poster'; video.src = origin + '/video'; document.body.append(video);
      const frame = document.createElement('iframe'); frame.src = origin + '/frame'; document.body.append(frame);
      const embed = document.createElement('embed'); embed.src = origin + '/embed'; document.body.append(embed);
      const link = document.createElement('link'); link.rel = 'stylesheet'; link.href = origin + '/style'; document.head.append(link);
      const box = document.createElement('div'); box.style.cssText = `height:20px;background-image:url(${origin}/css-image)`; document.body.append(box);
      loads.push(fetch(origin + '/fetch').catch(() => {}));
      Promise.all(loads).then(() => requestAnimationFrame(() => requestAnimationFrame(() => done(window.blockedResources))));
    JS
    assert blocked.any? { |url| url.include?("/image") }, blocked.inspect
    assert blocked.any? { |url| url.include?("/up?pdf-probe") }, blocked.inspect
    assert blocked.any? { |url| url.include?("/internal/meeting-minutes") }, blocked.inspect
    assert @requests.empty?, "Forbidden HTTP endpoint was contacted"
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "native Chromium produces agendas notes and minutes without contacting embedded media" do
    visit dated_agenda_pdf_source_path(token: DatedAgendaPdf.source_token(dated_agenda: @agenda, variant: "agenda"))
    base_url = URI(page.current_url).then { |uri| "#{uri.scheme}://#{uri.host}:#{uri.port}" }
    %w[agenda officer_notes].each do |variant|
      pdf = DatedAgendaPdf.render(dated_agenda: @agenda, variant:, base_url:)
      assert pdf.start_with?("%PDF")
      save_pdf(variant, pdf)
    end
    pdf = MeetingMinutesPdf.render(minutes: @minutes, base_url:)
    assert pdf.start_with?("%PDF")
    save_pdf("minutes", pdf)
    assert @requests.empty?, "Native PDF renderer contacted an embedded resource"
  end

  private

  def capture(name)
    return unless ENV["PDF_SECURITY_CAPTURE_DIR"]

    page.save_screenshot(File.join(ENV.fetch("PDF_SECURITY_CAPTURE_DIR"), "#{name}.png"))
  end

  def save_pdf(name, pdf)
    return unless ENV["PDF_SECURITY_CAPTURE_DIR"]

    File.binwrite(File.join(ENV.fetch("PDF_SECURITY_CAPTURE_DIR"), "#{name}.pdf"), pdf)
  end
end
