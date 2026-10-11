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

  private

  def position_graph(*titles)
    titles.map do |title|
      [ title.reload.attributes, title.position_capability_grants.order(:id).map(&:attributes),
        title.position_assignments.order(:id).map(&:attributes) ]
    end
  end
end
