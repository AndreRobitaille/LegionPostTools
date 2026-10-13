require "application_system_test_case"
require_relative "../support/membership_workspace_helpers"

class WorkspaceNavigationSystemTest < ApplicationSystemTestCase
  include MembershipWorkspaceHelpers

  setup do
    setup_membership_workspace
    @title.update!(name: "1st Vice Commander")
    @prior_buddy_enabled = ENV["MOBILE_BUDDY_CHECK_ENABLED"]
    ENV["MOBILE_BUDDY_CHECK_ENABLED"] = "true"
    page.current_window.resize_to(1400, 1000)
  end

  teardown do
    ENV["MOBILE_BUDDY_CHECK_ENABLED"] = @prior_buddy_enabled
    page.current_window.resize_to(1400, 1000)
  end

  test "administrator menu groups personal work and separate hubs at desktop tablet and phone widths" do
    %w[manage_settings use_mobile_buddy_checks publish_public_content].each do |capability|
      @officer.permission_grants.create!(capability:)
    end
    system_sign_in(@officer)
    [ [ 1400, 1000 ], [ 900, 900 ], [ 390, 900 ], [ 320, 560 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      visit root_path
      if width > 560
        assert_selector "nav.nav-bar a", count: 5
        assert_no_selector "nav.nav-bar a", text: "Buddy Checks"
      else
        assert_no_selector "nav.nav-bar"
      end
      click_button "Menu"
      within ".app-menu-panel" do
        assert_selector ".app-menu-group", text: /YOUR WORK.*Buddy Checks/m
        assert_selector ".app-menu-group", text: /POST DUTIES.*Officer tools/m
        assert_selector ".app-menu-group", text: /APPLICATION SETTINGS.*Administration/m
        assert_no_link "Membership", exact: true
      end
      assert_menu_layout
      capture_system_screenshot("menu-administrator-#{width}")
      find(".app-menu-btn").send_keys(:arrow_down)
      assert_equal width > 560 ? buddy_checks_root_path : root_path,
        page.evaluate_script("document.activeElement.getAttribute('href')")
      page.driver.browser.switch_to.active_element.send_keys(:escape)
      assert_selector ".app-menu-btn[aria-expanded=false]"
      assert_equal "Menu", page.evaluate_script("document.activeElement.textContent.trim()")
    end

    click_button "Menu"
    click_link "Officer tools", exact: true
    assert_current_path officer_tools_path
    assert_selector "h1", text: "Officer tools"
    assert_no_link "Import roster"
    assert_link "Membership", exact: false
    click_button "Menu"
    assert_selector ".app-menu-link[href='#{officer_tools_path}'][aria-current=page]"
    click_link "Administration", exact: true
    assert_current_path admin_root_path
    assert_selector "h1", text: "Administration"
    assert_no_selector ".workspace-group--meeting-work"
    assert_no_selector ".workspace-group--membership"
    click_button "Menu"
    assert_selector ".app-menu-link[href='#{admin_root_path}'][aria-current=page]"
    find(".app-menu-btn").send_keys(:arrow_up)
    assert_equal "Sign out", page.evaluate_script("document.activeElement.textContent.trim()")
    assert page.evaluate_script("document.querySelector('.app-menu-panel').scrollTop > 0")
    capture_system_screenshot("menu-short-phone-signout")
    click_button "Sign out"
    assert_current_path new_session_path
    visit officer_tools_path
    assert_current_path new_session_path
  end

  test "personal Buddy Checks and assigned calls do not grant officer or administration access" do
    @volunteer.permission_grants.create!(capability: "use_mobile_buddy_checks")
    system_sign_in(@volunteer)
    page.current_window.resize_to(390, 900)
    visit root_path
    click_button "Menu"
    within ".app-menu-panel" do
      assert_selector ".app-menu-group", text: /YOUR WORK.*Buddy Checks.*Your assigned calls/m
      assert_no_link "Officer tools"
      assert_no_link "Administration"
    end
    capture_system_screenshot("menu-assigned-caller-390")
    click_link "Your assigned calls"
    assert_current_path membership_follow_up_path
    assert_text @member.roster_display_name
    assert_no_link "Membership overview"
    click_button "Menu"
    click_link "Buddy Checks", exact: true
    assert_current_path buddy_checks_root_path
    assert_selector "h1", text: "Buddy Checks"
    visit officer_tools_path
    assert_current_path root_path
    visit admin_root_path
    assert_current_path root_path
    @drive.update!(closed_at: Time.current)
    visit root_path
    click_button "Menu"
    assert_no_link "Your assigned calls"
    assert_link "Buddy Checks", exact: true
  end

  test "first vice reaches Membership through Officer tools and ending the office removes access" do
    system_sign_in(@officer)
    visit root_path
    click_button "Menu"
    assert_no_link "Administration"
    assert_link "Buddy Checks", exact: true
    click_link "Officer tools"
    assert_current_path officer_tools_path
    capture_system_screenshot("officer-first-vice-1400")
    click_link "Membership", exact: false
    assert_current_path membership_root_path
    click_button "Menu"
    assert_selector ".app-menu-link[href='#{officer_tools_path}'][aria-current=page]"
    @office.update!(ends_on: Organization.current_local_date - 1)
    visit root_path
    click_button "Menu"
    assert_no_link "Officer tools"
    visit officer_tools_path
    assert_current_path root_path
    visit membership_root_path
    assert_text "You do not have a current membership assignment or membership officer access."
  end

  test "ordinary member sees member destinations and account without work headings" do
    system_sign_in(@other)
    [ 1400, 390 ].each do |width|
      page.current_window.resize_to(width, 900)
      visit root_path
      click_button "Menu"
      within ".app-menu-panel" do
        assert_no_selector ".app-menu-heading", text: "YOUR WORK"
        assert_no_link "Officer tools"
        assert_no_link "Administration"
        assert_link "Your profile"
        assert_button "Sign out"
      end
      assert_menu_layout
      capture_system_screenshot("menu-member-#{width}")
    end
  end

  test "removing settings access keeps current Post duties and removes administration on the next request" do
    settings = @officer.permission_grants.create!(capability: "manage_settings")
    system_sign_in(@officer)
    visit admin_root_path
    assert_selector "h1", text: "Administration"
    settings.destroy!
    visit root_path
    click_button "Menu"
    assert_no_link "Administration"
    assert_link "Officer tools"
    visit admin_root_path
    assert_current_path officer_tools_path
    assert_no_link "Import roster"
    assert_link "Membership", exact: false
    visit new_admin_roster_import_path
    assert_current_path root_path
  end

  private

  def assert_menu_layout
    assert page.evaluate_script("document.documentElement.scrollWidth <= innerWidth"), "No horizontal overflow"
    assert page.evaluate_script(<<~JS), "Menu fits the viewport and retains readable full-size targets"
      (() => {
        const panel = document.querySelector('.app-menu-panel');
        const bounds = panel.getBoundingClientRect();
        return bounds.left >= 0 && bounds.right <= innerWidth && bounds.bottom <= innerHeight &&
          [...panel.querySelectorAll('.app-menu-link')].filter(link => link.getClientRects().length).every(link =>
            link.getBoundingClientRect().height >= 44 && parseFloat(getComputedStyle(link).fontSize) >= 16) &&
          [...panel.querySelectorAll('.app-menu-heading')].every(label => parseFloat(getComputedStyle(label).fontSize) >= 13);
      })()
    JS
  end
end
