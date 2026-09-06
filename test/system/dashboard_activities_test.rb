require "application_system_test_case"

class DashboardActivitiesTest < ApplicationSystemTestCase
  test "meeting documents stay ahead of activities on desktop and phone" do
    organization = Organization.create!(name: "Example Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    member = User.create!(person: Person.create!(first_name: "Jane", last_name: "Member"), email_address: "dashboard-member@example.com")
    body = organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    type = organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    past = create_meeting!(organization:, meeting_body: body, meeting_type: type, starts_at: 1.week.ago, location_name: "Post hall")
    upcoming = create_meeting!(organization:, meeting_body: body, meeting_type: type, starts_at: 1.week.from_now, location_name: "Post hall")
    [ past, upcoming ].each do |meeting|
      agenda = DatedAgenda.create_from_template!(meeting:)
      agenda.approve!(member)
      agenda.publish!(member)
    end
    event = organization.calendar_events.create!(title: "Community breakfast", starts_at: 2.days.from_now.in_time_zone(organization.calendar_time_zone).change(hour: 8), location: "Post hall", visibility: "public", created_by: member, updated_by: member)
    organization.calendar_events.create!(title: "Veterans Day community celebration planning meeting", starts_at: 4.days.from_now.in_time_zone(organization.calendar_time_zone).change(hour: 18), location: "Community center meeting room", calendar_category: "planning_meeting", created_by: member, updated_by: member)
    organization.calendar_events.create!(title: "Post family picnic", starts_at: 12.days.from_now.in_time_zone(organization.calendar_time_zone).change(hour: 12), all_day: true, location: "Riverside park", created_by: member, updated_by: member)

    system_sign_in(member)
    [ [ 1400, 1500, "desktop" ], [ 390, 844, "mobile" ] ].each do |width, height, name|
      page.current_window.resize_to(width, height)
      visit root_path
      assert_selector ".member-meeting-card", count: 2
      assert_selector ".member-meeting-card a", text: "View agenda", count: 2
      assert_selector ".dashboard-activity", count: 3
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
      assert page.evaluate_script("document.querySelector('.dashboard-activities').getBoundingClientRect().top > document.querySelectorAll('.member-meeting-card')[1].getBoundingClientRect().bottom")
      page.save_screenshot("/tmp/dashboard-activities-#{name}.png")
      find(".member-dashboard-all-meetings", text: "Browse all meetings").send_keys(:tab)
      assert_selector ".dashboard-activity:focus-visible"
      focused_outline = page.evaluate_script("getComputedStyle(document.activeElement).outlineStyle")
      assert_equal "solid", focused_outline
      page.save_screenshot("/tmp/dashboard-activities-#{name}-focus.png")
      first(".dashboard-activity").click
      assert_current_path calendar_event_path(event)
    end
  ensure
    page.current_window.resize_to(1400, 1000)
  end
end
