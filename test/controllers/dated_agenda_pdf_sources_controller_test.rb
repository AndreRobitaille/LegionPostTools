require "test_helper"

class DatedAgendaPdfSourcesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      locality: "Two Rivers, Wisconsin",
      mailing_address: "P.O. Box 11\nTwo Rivers, WI 54241",
      public_email: "wipost165@gmail.com",
      default_location_name: "Manitowoc Rifle and Pistol Club",
      default_location_address: "7227 Sandy Hill Lane\nTwo Rivers, WI 54241",
      timezone: "America/Chicago"
    )
    @meeting_body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting_type = @organization.meeting_types.create!(
      name: "Membership Meeting",
      slug: "membership-meeting",
      position: 1,
      active: true
    )
    @agenda = create_dated_agenda!(organization: @organization,
      meeting_body: @meeting_body,
      meeting_type: @meeting_type,
      starts_at: Time.zone.local(2026, 7, 7, 19, 0),
      title: "Membership Meeting — July 7, 2026",
      status: "draft"
    )
    @item = @agenda.dated_agenda_items.create!(
      position: 1,
      title: "Roll Call",
      behavior_type: "roll_call",
      active: true,
      body: "Member wording withheld",
      show_wording_on_agenda: false,
      commander_notes: "Call each officer by office."
    )
    position_title = @organization.position_titles.create!(
      name: "Commander",
      display_order: 1,
      required_by_default: true,
      active: true
    )
    commander = Person.create!(first_name: "Pat", last_name: "Commander")
    @item.roll_call_entries.create!(
      position_title:,
      person: commander,
      office_name: position_title.name,
      person_name: commander.full_name,
      position: 1
    )
  end

  test "member source is a chrome-free print document without officer content" do
    get dated_agenda_pdf_source_path(token: token_for("agenda"))

    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    assert_select "body.print-body"
    assert_select ".agenda-masthead h1", text: "Membership Meeting — Agenda"
    assert_select "img.agenda-emblem[alt='']"
    assert_select ".agenda-meeting-location", text: /Manitowoc Rifle and Pistol Club.*7227 Sandy Hill Lane/m
    assert_select "ol.agenda-chapter-items > li.agenda-item", minimum: 1
    assert_select ".commander-cue", count: 0
    assert_select ".roll-call-table", count: 0
    assert_select "body", text: /Call each officer/, count: 0
    assert_select "body", text: /Member wording withheld/, count: 0
    assert_select "nav", count: 0
  end

  test "officer source includes private cues and roll call" do
    get dated_agenda_pdf_source_path(token: token_for("officer_notes"))

    assert_response :success
    assert_select ".agenda-meeting-heading h1", text: "Membership Meeting — Commander & Adjutant notes copy"
    assert_select ".commander-cue", text: /Call each officer/
    assert_select ".roll-call-table", text: /Commander.*Pat Commander/m
    assert_select "body", text: /Member wording withheld/, count: 0
  end

  test "source restricts resource requests and marks embedded images without editing their source" do
    html = '<p style="text-align: center">Retained wording</p><img src="http://127.0.0.1:9999/private" alt="Finance chart">'
    @item.update!(body: html, show_wording_on_agenda: true, commander_notes: html)
    original = @item.body.body.to_html

    %w[agenda officer_notes].each do |variant|
      get dated_agenda_pdf_source_path(token: token_for(variant)), headers: { "HTTPS" => "on", "X-Forwarded-Proto" => "https" }
      assert_response :success
      policy = response.headers.fetch("Content-Security-Policy")
      assert_includes policy, "default-src 'none'"
      assert_includes policy, "base-uri 'none'"
      assert_includes policy, "form-action 'none'"
      assert_includes policy, "style-src-attr 'unsafe-inline'"
      assert_not_includes policy, "'self'"
      assert_not_includes policy, "9999"
      assert_includes policy, "http://www.example.com/assets/"
      assert_not_includes policy, "https://"
      assert_select "head style[nonce]" do |styles|
        assert_includes policy, "'nonce-#{styles.first['nonce']}'"
      end
      assert_select ".agenda-item-body img, .commander-cue img", count: 0
      assert_select ".pdf-omitted-media", text: "Image omitted from PDF: Finance chart", count: variant == "agenda" ? 1 : 2
      assert_select ".agenda-item-body p", text: "Retained wording" do |paragraphs|
        assert_match(/text-align:\s*center/, paragraphs.first["style"].to_s)
      end
      assert_select "img.agenda-emblem"
    end
    assert_equal original, @item.reload.body.body.to_html
  end

  test "source rejects invalid tokens" do
    get dated_agenda_pdf_source_path(token: "invalid")

    assert_response :not_found
  end

  test "source rejects non-loopback requests" do
    get dated_agenda_pdf_source_path(token: token_for("agenda")), headers: { "REMOTE_ADDR" => "203.0.113.9" }

    assert_response :not_found
  end

  private

  def token_for(variant)
    DatedAgendaPdf.source_token(dated_agenda: @agenda, variant:)
  end
end
