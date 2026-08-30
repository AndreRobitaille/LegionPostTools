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
    @agenda = @organization.dated_agendas.create!(
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
    assert_select ".agenda-meeting-heading h1", text: "Membership Meeting — Commander's working copy"
    assert_select ".commander-cue", text: /Call each officer/
    assert_select ".roll-call-table", text: /Commander.*Pat Commander/m
    assert_select "body", text: /Member wording withheld/, count: 0
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
