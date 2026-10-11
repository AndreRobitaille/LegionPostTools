require "application_system_test_case"

class AdminWorkspaceSystemTest < ApplicationSystemTestCase
  setup do
    page.current_window.resize_to(1400, 1100)
    @organization = Organization.create!(name: "Harbor Post 204", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    person = Person.create!(first_name: "Morgan", last_name: "Reed")
    @user = User.create!(person:, email_address: "morgan@example.com", email_verified_at: Time.current)
  end

  test "administrator finds roster actions in missing stale and current states at desktop and phone widths" do
    grant "manage_settings", "publish_public_content"
    system_sign_in(@user)

    [ [ "missing", nil ], [ "stale", 31.days.ago ], [ "current", 2.days.ago ] ].each do |state, imported_at|
      RosterImport.delete_all
      if imported_at
        RosterImport.create!(uploaded_filename: "synthetic.csv", status: "completed", imported_at:)
      end

      [ 1400, 900, 390, 320 ].each do |width|
        page.current_window.resize_to(width, 1100)
        visit admin_root_path
        assert_selector "h1", text: "Administration"
        assert_selector "h2", text: /meeting work/i
        assert_selector "h2", text: /people and roster/i
        assert_link "Import history"
        assert_link "Sync email audience"
        if state == "current"
          assert_selector ".workspace-roster-status", text: "Current"
          assert_no_selector ".workspace-attention"
        else
          assert_selector ".workspace-attention h3", text: state == "missing" ? "Import your first roster" : "Roster import is due"
          assert_selector ".workspace-roster-status", text: state == "missing" ? "Not imported" : "Import due"
        end
        assert_readable_workspace
        capture_system_screenshot("admin-#{state}-#{width}")
      end
    end

    find(".workspace-group--meeting-work .workspace-destination", text: "Meetings").hover
    assert_readable_workspace
    within ".workspace-group--people-roster" do
      click_link "Import roster"
    end
    assert_current_path new_admin_roster_import_path
    assert_selector "h1", text: "Import roster"

    visit admin_root_path
    click_link "Import history"
    assert_current_path admin_roster_imports_path

    visit admin_root_path
    click_link "Sync email audience"
    assert_current_path new_admin_loops_roster_sync_path
    assert_selector "h1", text: "Sync roster to Loops"
  end

  test "agenda manager navigates from the phone menu and keyboard with visible focus" do
    grant "manage_agendas"
    system_sign_in(@user)
    page.current_window.resize_to(390, 900)
    visit root_path
    click_button "Menu"
    click_link "Officer tools"

    assert_current_path admin_root_path
    assert_selector "h1", text: "Officer tools"
    assert_no_selector ".workspace-attention"
    assert_no_selector ".workspace-group--access"
    assert_readable_workspace
    capture_system_screenshot("agenda-manager-390")

    # Tab from one actual destination to the next and activate it with Enter.
    find(".workspace-destination", text: "Meetings").send_keys(:tab)
    assert_equal admin_endeavors_path, page.evaluate_script("document.activeElement.getAttribute('href')")
    assert_equal "3px", page.evaluate_script("getComputedStyle(document.activeElement).outlineWidth")
    assert_equal "solid", page.evaluate_script("getComputedStyle(document.activeElement).outlineStyle")
    assert_readable_workspace
    capture_system_screenshot("agenda-manager-focus-390")
    page.driver.browser.switch_to.active_element.send_keys(:enter)
    assert_current_path admin_endeavors_path

    visit admin_root_path
    click_link "Meeting types", exact: false
    assert_current_path admin_meeting_types_path
    find("a.back", text: "Officer tools").click
    assert_current_path admin_root_path
    click_link "Background Jobs", exact: false
    assert_current_path admin_jobs_path

    page.current_window.resize_to(1400, 1100)
    visit admin_root_path
    capture_system_screenshot("agenda-manager-1400")
  end

  test "publisher has a readable sparse workspace and cannot open settings" do
    grant "publish_public_content"
    system_sign_in(@user)

    [ 1400, 390 ].each do |width|
      page.current_window.resize_to(width, 900)
      visit admin_root_path
      assert_selector ".workspace-group", count: 1
      assert_selector "h2", text: /public website/i
      assert_no_link "Website connections"
      assert_no_link "Background Jobs"
      assert_readable_workspace
      capture_system_screenshot("publisher-#{width}")
    end

    click_link "Publishing", exact: false
    assert_current_path admin_website_publications_path
    visit admin_website_access_tokens_path
    assert_current_path root_path
    visit admin_root_path
    assert_no_link "Website connections"
  end

  test "record viewer follows Meetings and loses workspace access on the next request after revocation" do
    grant "view_internal_records"
    system_sign_in(@user)
    visit admin_root_path
    assert_selector ".workspace-destination", count: 1
    assert_no_link "Background Jobs"
    within ".workspace-group--meeting-work" do
      click_link "Meetings", exact: false
    end
    assert_current_path admin_meetings_path

    visit admin_jobs_path
    assert_current_path root_path
    @user.permission_grants.find_by!(capability: "view_internal_records").destroy!
    visit admin_root_path
    assert_current_path root_path
    click_button "Menu"
    assert_no_link "Officer tools"
    visit admin_meetings_path
    assert_current_path root_path
  end

  private

  def grant(*capabilities)
    capabilities.each { |capability| @user.permission_grants.create!(capability:) }
  end

  def assert_readable_workspace
    assert page.evaluate_script("document.documentElement.scrollWidth <= innerWidth"), "No horizontal page overflow"
    assert page.evaluate_script(<<~JS), "Destination and attention links have 44px targets"
      [...document.querySelectorAll('.workspace-destination, .workspace-attention a')]
        .every(link => link.getBoundingClientRect().height >= 44)
    JS
    assert page.evaluate_script(<<~JS), "Working text meets the product's readability floors"
      (() => {
        const minimums = { '.page-sub': 16, '.mrow-name': 16, '.mrow-sub': 14,
          '.sec-head-label': 13, '.workspace-roster-status': 14,
          '.workspace-attention p': 16, '.workspace-attention a': 16,
          '.officer-workspace-context small': 14 };
        return Object.entries(minimums).every(([selector, minimum]) =>
          [...document.querySelectorAll('.admin-workspace ' + selector)]
            .every(element => parseFloat(getComputedStyle(element).fontSize) >= minimum));
      })()
    JS
    assert page.evaluate_script(<<~'JS'), "Working text has at least 4.5:1 contrast against its rendered background"
      (() => {
        const luminance = color => {
          const channels = color.match(/[0-9.]+/g);
          if (!channels || channels.length < 3) throw new Error('Unrecognized rendered color: ' + color);
          const rgb = channels.slice(0, 3).map(value => Number(value) / 255);
          const linear = rgb.map(value => value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4);
          return linear.reduce((sum, value, index) => sum + value * [0.2126, 0.7152, 0.0722][index], 0);
        };
        return [...document.querySelector('.admin-workspace').querySelectorAll('.page-sub, .mrow-name, .mrow-sub, .sec-head-label, .workspace-roster-status, .workspace-attention p, .workspace-attention a, .officer-workspace-context small')].every(element => {
          let ancestor = element;
          let background;
          while (ancestor) {
            background = getComputedStyle(ancestor).backgroundColor;
            if (background !== 'rgba(0, 0, 0, 0)' && background !== 'transparent') break;
            ancestor = ancestor.parentElement;
          }
          const foreground = luminance(getComputedStyle(element).color);
          const behind = luminance(background);
          return (Math.max(foreground, behind) + 0.05) / (Math.min(foreground, behind) + 0.05) >= 4.5;
        });
      })()
    JS
  end
end
