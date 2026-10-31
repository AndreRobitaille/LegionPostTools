require "application_system_test_case"

class PositionTitlesSystemTest < ApplicationSystemTestCase
  setup do
    @original_detailed_exceptions = Rails.application.env_config.fetch("action_dispatch.show_detailed_exceptions")
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false
    @organization = Organization.create!(name: "Configured synthetic Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    admin = User.create!(person: Person.create!(first_name: "Position", last_name: "Administrator"), email_address: "position-admin@example.test")
    admin.permission_grants.create!(capability: "manage_settings")
    @own = @organization.position_titles.create!(name: "Configured Historian")
    other = Organization.create!(name: "Separate synthetic Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @foreign = other.position_titles.create!(name: "Separate Post Historian")
    @foreign.position_capability_grants.create!(capability: "manage_minutes")
    @foreign.position_assignments.create!(person: Person.create!(first_name: "Separate", last_name: "Officer"), starts_on: Date.new(2026, 1, 1))
    system_sign_in(admin)
  end

  teardown do
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = @original_detailed_exceptions
  end

  test "End role uses the saved Post date through real controls on desktop and phone" do
    admin = User.find_by!(email_address: "position-admin@example.test")
    [
      [ "America/Chicago", Time.utc(2026, 11, 13, 5, 59), Date.new(2026, 11, 12), "12 NOV 2026", 1400 ],
      [ "Asia/Tokyo", Time.utc(2026, 11, 12, 15), Date.new(2026, 11, 13), "13 NOV 2026", 390 ]
    ].each do |zone, instant, expected_date, visible_date, width|
      travel_to instant
      @organization.update!(timezone: zone)
      person = Person.create!(first_name: "Synthetic", last_name: "Local Officer #{width}")
      assignment = @own.position_assignments.create!(person:, starts_on: Date.new(2026, 1, 1))
      system_sign_in(admin)
      page.current_window.resize_to(width, 1000)
      visit person_path(person)
      click_button "End role"
      assert_no_button "End role"
      assert_current_path person_path(person)
      assert_equal expected_date, assignment.reload.ends_on
      assert_selector ".rd", text: visible_date
      assert_selector ".office", text: /Configured Historian/i
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
      page.execute_script("arguments[0].scrollIntoView({block: 'center'})", find(".role"))
      capture_system_screenshot("end-role-local-date-#{width}")
    end
  ensure
    travel_back
    page.current_window.resize_to(1400, 1400)
  end

  test "foreign position submission preserves saved authority and own controls still work" do
    [ [ 1400, 1400 ], [ 390, 844 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      visit admin_position_titles_path
      assert_no_text @foreign.name
      own_row = ".pos[data-reorder-id='#{@own.id}']"
      original = position_graph(@own, @foreign)
      within own_row do
        form = find_button("Deactivate").find(:xpath, "..")
        # Native submission exposes the standard error page. Legitimate controls
        # below keep their ordinary Turbo behavior.
        page.execute_script("arguments[0].action = arguments[1]; arguments[0].dataset.turbo = 'false'", form, admin_position_title_path(@foreign))
        click_button "Deactivate"
      end
      assert_text "The page you were looking for doesn't exist."
      assert_equal original, position_graph(@own, @foreign)

      visit admin_position_titles_path
      within own_row do
        click_button "Deactivate"
        assert_text "Inactive"
        assert_not @own.reload.active?
        click_button "Activate"
        assert_text "Active"
        assert_predicate @own.reload, :active?
        click_button "Grant membership access"
        assert_text "Full membership access"
        assert_predicate @own.reload, :grants_full_membership_access?
        click_button "Remove membership access"
        assert_no_text "Full membership access"
        assert_not @own.reload.grants_full_membership_access?
      end
      assert_equal original.last, position_graph(@foreign).last
      assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth"), "Position screen overflow at #{width}px"
      capture_system_screenshot("positions-restored-#{width}")
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "administrators save member contact guidance and recover from invalid examples on desktop and phone" do
    @own.position_assignments.create!(person: Person.create!(first_name: "Synthetic", last_name: "Historian"), starts_on: Date.new(2020, 1, 1))
    [ [ 1400, 1200 ], [ 390, 1000 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      visit admin_position_titles_path
      within ".pos[data-reorder-id='#{@own.id}']" do
        click_link "Edit contact guidance"
      end
      assert_current_path edit_admin_position_title_path(@own)
      assert_text "current officer's name"
      original = @own.reload.attributes.slice("contact_description", "contact_examples", "website_officer_listing")
      description = "Preserves our Post's photographs and history."
      fill_in "Responsibility", with: description
      fill_in "Contact them when…", with: "You have an old photograph.\nYou want to identify a past officer.\nOne example too many."
      click_button "Save guidance"
      assert_selector ".error-summary", text: /up to two examples/
      assert_field "Responsibility", with: description
      assert_equal original, @own.reload.attributes.slice("contact_description", "contact_examples", "website_officer_listing")

      examples = "You have an old photograph.\nYou want to identify a past officer."
      fill_in "Contact them when…", with: examples
      check "List current officers on the public website"
      assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth"), "Guidance editor overflow at #{width}px"
      assert page.all("textarea").all? { |field| field.evaluate_script("parseFloat(getComputedStyle(this).fontSize) >= 16") }
      click_button "Save guidance"
      assert_current_path admin_position_titles_path
      assert_equal description, @own.reload.contact_description
      assert_equal examples.lines.map(&:strip), @own.contact_examples
      assert @own.website_officer_listing?
      visit edit_admin_position_title_path(@own)
      assert_field "Contact them when…", with: examples
      page.scroll_to(:top)
      capture_system_screenshot("contact-guidance-editor-#{width}")
      visit post_contact_path
      within ".post-contact-officer", text: @own.name do
        assert_text description
        assert_text "You have an old photograph."
        assert_text "You want to identify a past officer."
      end
    end

    assistant = @organization.position_titles.create!(name: "Assistant Chaplain")
    visit edit_admin_position_title_path(assistant)
    assert_text "Assists the Chaplain."
    assert_no_selector "textarea"
    assert_unchecked_field "List current officers on the public website"
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  private

  def position_graph(*titles)
    titles.map do |title|
      [ title.reload.attributes, title.position_capability_grants.order(:id).map(&:attributes),
        title.position_assignments.order(:id).map(&:attributes) ]
    end
  end
end
