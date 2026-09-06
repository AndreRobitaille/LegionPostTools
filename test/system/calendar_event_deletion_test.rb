require "application_system_test_case"

class CalendarEventDeletionSystemTest < ApplicationSystemTestCase
  test "manager can cancel confirmation or delete at desktop and phone widths" do
    org = Organization.create!(name: "Example Post", unit_type: "american_legion_post")
    Installation.singleton.update!(setup_completed_at: Time.current)
    manager = User.create!(person: Person.create!(first_name: "Calendar", last_name: "Manager"), email_address: "manager@example.com")
    manager.permission_grants.create!(capability: "manage_settings")
    system_sign_in(manager)
    [ 1280, 390 ].each do |width|
      event = org.calendar_events.create!(title: "Duplicate volunteer meeting", starts_at: Time.current, created_by: manager, updated_by: manager)
      page.current_window.resize_to(width, 1000)
      visit edit_calendar_event_path(event)
      click_button "Delete event"
      assert_selector "dialog[open]", text: event.title
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
      page.save_screenshot("/tmp/calendar-delete-#{width}.png")
      within "dialog[open]" do
        click_button "Cancel"
      end
      assert_no_selector "dialog[open]"
      assert CalendarEvent.exists?(event.id)
      click_button "Delete event"
      within "dialog[open]" do
        click_button "Delete event"
      end
      assert_text "Calendar event deleted."
      assert_not CalendarEvent.exists?(event.id)
      protected_event = org.calendar_events.create!(title: "PEC meeting", starts_at: Time.current, created_by: manager, updated_by: manager)
      visit edit_calendar_event_path(protected_event)
      assert_no_button "Delete event"
      assert_text "Member and officer meeting entries cannot be deleted from the calendar."
    end
  ensure
    page.current_window.resize_to(1400, 1000)
  end
end
