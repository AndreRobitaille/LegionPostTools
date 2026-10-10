require "test_helper"

class CalendarPdfSourcesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Example Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @member = User.create!(person: Person.create!(first_name: "Calendar", last_name: "Member"), email_address: "pdf-calendar@example.test")
    @member.permission_grants.create!(capability: "manage_settings")
    @event = @organization.calendar_events.create!(title: "Members breakfast", starts_at: @organization.calendar_time_zone.local(2026, 9, 12, 9),
      description: "Bring <em>two trays</em>.\n\nUse the side entrance.", created_by: @member, updated_by: @member)
    @public_event = @organization.calendar_events.create!(title: "Community ceremony", starts_at: @event.starts_at, visibility: "public", calendar_category: "honor_guard",
      description: "Public ceremony details", created_by: @member, updated_by: @member)
    endeavor = @organization.endeavors.create!(title: "Private endeavor title", details: "Internal narrative", created_by: @member)
    @public_event.update!(endeavor: endeavor)
    @other_organization = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/New_York")
    @other_organization.calendar_events.create!(title: "Other Post event", starts_at: @event.starts_at, created_by: @member, updated_by: @member)
  end

  test "source renders both layouts without a member session or officer controls" do
    get calendar_pdf_source_path(token: token)

    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    assert_select "body.print-body .app-main .calendar-workspace"
    assert_select ".calendar-month .calendar-print-section", text: "Month overview"
    assert_select ".calendar-schedule .calendar-print-section", text: "Detailed schedule"
    assert_select ".calendar-print-heading time", text: "September 2026", count: 2
    assert_select ".calendar-print-description", text: /Bring <em>two trays<\/em>/
    assert_select ".calendar-print-description em, script, .app-header, .calendar-page-header, .calendar-officer-tools", count: 0
    assert_no_match(/Private endeavor title|Internal narrative|Other Post event/, response.body)
    assert_select ".calendar-block-print-time", text: "09:00", count: 2
  end

  test "source keeps the signed filters despite unsigned query overrides" do
    get calendar_pdf_source_path(token: token(categories: [ "honor_guard" ]), categories: [ "other" ], start_date: "2027-05-01", view: "deadlines")
    assert_response :success
    assert_select ".calendar-grid-event:not([hidden])", text: /Community ceremony/
    assert_select ".calendar-grid-event[hidden]", text: /Members breakfast/
    assert_select ".calendar-row:not([hidden])", text: /Community ceremony/
    assert_select ".calendar-row[hidden]", text: /Members breakfast/
    assert_select ".calendar-print-heading time", text: "September 2026", count: 2
  end

  test "empty category selection hides all events without reverting to defaults" do
    get calendar_pdf_source_path(token: token(categories: []))
    assert_response :success
    assert_select ".calendar-grid-event:not([hidden]), .calendar-row:not([hidden])", count: 0
  end

  test "public preview excludes member events meetings and private endeavor context" do
    body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    create_meeting!(organization: @organization, meeting_body: body, starts_at: @event.starts_at, title: "Private membership meeting")
    get calendar_pdf_source_path(token: token(view: "public"))
    assert_response :success
    assert_match(/Community ceremony/, response.body)
    assert_no_match(/Members breakfast|Private membership meeting|Private endeavor title|Internal narrative|Other Post event/, response.body)
  end

  test "source uses the organization in the signature" do
    month = CalendarMonth.new(organization: @other_organization, date: Date.new(2026, 9, 1))
    get calendar_pdf_source_path(token: CalendarPdf.source_token(organization: @other_organization, month: month))
    assert_response :success
    assert_select ".calendar-print-post", text: "Other Post", count: 2
    assert_match(/Other Post event/, response.body)
    assert_no_match(/Members breakfast|Community ceremony/, response.body)
    assert_select ".calendar-block-print-time", text: "10:00"
  end

  test "source limits resources to allowed print assets" do
    get calendar_pdf_source_path(token: token), headers: { "HTTPS" => "on", "X-Forwarded-Proto" => "https" }
    assert_response :success
    policy = response.headers.fetch("Content-Security-Policy")
    assert_includes policy, "default-src 'none'"
    assert_includes policy, "form-action 'none'"
    assert_includes policy, "http://www.example.com/assets/tailwind-"
    assert_not_includes policy, "'self'"
    assert_not_includes policy, "https://"
  end

  test "source rejects missing invalid expired and non-local tokens" do
    get calendar_pdf_source_path
    assert_response :not_found
    get calendar_pdf_source_path(token: "invalid")
    assert_response :not_found
    signed = token
    travel 61.seconds do
      get calendar_pdf_source_path(token: signed)
      assert_response :not_found
    end
    get calendar_pdf_source_path(token: token), headers: { "REMOTE_ADDR" => "203.0.113.10" }
    assert_response :not_found
  end

  test "source rejects a missing organization" do
    payload = CalendarPdf.verify_source_token!(token).merge("organization_id" => -1)
    signed = Rails.application.message_verifier("calendar-pdf-source").generate(payload)
    get calendar_pdf_source_path(token: signed)
    assert_response :not_found
  end

  private

  def token(view: "events", categories: nil)
    month = CalendarMonth.new(organization: @organization, date: Date.new(2026, 9, 1), view: view, categories: categories)
    CalendarPdf.source_token(organization: @organization, month: month)
  end
end
