require "application_system_test_case"

class PostContactsSystemTest < ApplicationSystemTestCase
  setup do
    @organization = Organization.create!(name: "Example American Legion Post", unit_type: "american_legion_post",
      timezone: "America/Chicago", public_email: "wipost165@gmail.com", mailing_address: "PO Box 100\nExample, WI 53000")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @member = User.create!(person: Person.create!(first_name: "Alex", last_name: "Member"), email_address: "member@example.test")
    [
      [ "Commander", "Morgan", "Reed", "morgan@example.test", "(920) 555-0101", "Reed, Morgan Sr." ],
      [ "1st Vice Commander", "Patricia", "Ellis", "patricia@example.test", "(920) 555-0102" ],
      [ "Adjutant", "James", "Bennett", "james@example.test", nil ],
      [ "Chaplain", "Robin", "Hayes", nil, "(920) 555-0103" ],
      [ "Service Officer", "Casey", "Brooks", "casey@example.test", "(920) 555-0104", "Brooks, Casey Jr." ],
      [ "Historian", "Taylor", "Lane", nil, nil ],
      [ "Assistant Chaplain", "Drew", "Parker", "drew@example.test", nil ]
    ].each_with_index do |(office, first_name, last_name, email, phone, roster_name), index|
      title = @organization.position_titles.create!(name: office, display_order: index)
      person = Person.create!(first_name:, last_name:, roster_name: roster_name || "#{last_name}, #{first_name}", email_address: email, phone_number: phone)
      PositionAssignment.create!(person:, position_title: title, starts_on: Organization.current_local_date - 30)
    end
  end

  teardown do
    page.current_window.resize_to(1400, 1000)
  end

  test "members find Post and officer contacts through desktop and phone navigation" do
    page.current_window.resize_to(1400, 1300)
    system_sign_in(@member)
    [ [ 1400, 1600 ], [ 900, 1100 ], [ 390, 1000 ], [ 320, 900 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      visit root_path
      click_button "Menu" if width <= 560
      click_link "Contact the Post", exact: true
      assert_current_path post_contact_path
      assert_selector "h1", text: "Contact the Post"
      assert_link "wipost165@gmail.com", href: "mailto:wipost165@gmail.com"
      assert_selector ".post-contact-name", count: 7
      within ".post-contact-choices" do
        assert_selector ".post-contact-name", exact_text: "Morgan Reed, Sr."
        assert_selector ".post-contact-name", exact_text: "Casey Brooks, Jr."
        assert_text "You have a concern about a Post decision or how you were treated."
        assert_text "You need help getting started with a VA claim."
        assert_selector ".post-contact-examples li", count: 4
      end
      assert_selector ".post-contact-details a[href^='tel:']", count: 4
      assert_selector ".post-contact-details a[href^='mailto:']", count: 5
      assert_link "(920) 555-0101", href: "tel:9205550101"
      assert_no_selector ".post-contact-page button, .post-contact-page .btn-primary, .post-contact-page .btn-secondary"
      within ".post-contact-officer", text: "Assistant Chaplain" do
        assert_text "Assists the Chaplain."
        assert_no_selector ".post-contact-examples"
        assert_link "drew@example.test"
      end
      assert_selector ".post-contact-note", text: "No direct contact details listed."
      within ".post-contact-officer", text: "Historian" do
        assert_link "wipost165@gmail.com", href: "mailto:wipost165@gmail.com?subject=For%20the%20Historian"
      end
      assert_contact_layout
      page.scroll_to(:top)
      capture_system_screenshot("contact-the-post-#{width}")
      if width == 390
        service_officer = find(".post-contact-choice", text: "Service Officer")
        page.scroll_to(service_officer, align: :top)
        assert_in_delta 0, service_officer.evaluate_script("this.getBoundingClientRect().top"), 1
        capture_system_screenshot("contact-the-post-service-officer-390")
        page.scroll_to(find(".post-contact-officer", text: "Assistant Chaplain"), align: :bottom)
        capture_system_screenshot("contact-the-post-assistant-390")
      end
    end

    click_link "View member directory"
    assert_current_path people_path
    assert_selector "h1", text: "People"
    click_button "Menu"
    click_link "Contact the Post", exact: true
    assert_current_path post_contact_path
    click_link "Morgan Reed, Sr."
    assert_selector "h1", text: "Reed, Morgan Sr."
    assert_link "morgan@example.test", href: "mailto:morgan@example.test"
  end

  test "long contact details wrap and keyboard focus survives while ended offices disappear on later visits" do
    page.current_window.resize_to(390, 1000)
    system_sign_in(@member)
    commander = PositionAssignment.joins(:position_title).find_by!(position_titles: { name: "Commander" })
    commander.person.update!(first_name: "Morgan-Alexandra", last_name: "Reed-Worthington",
      roster_name: "Reed-Worthington, Morgan-Alexandra Sr.", email_address: "morgan.alexandra.reed.worthington@example.test")
    @organization.update!(public_email: "general.questions.for.our.american.legion.post@example.test")
    visit post_contact_path
    assert_contact_layout
    commander_link = find_link("Morgan-Alexandra Reed-Worthington, Sr.")
    commander_link.send_keys(:tab)
    assert_equal "mailto:morgan.alexandra.reed.worthington@example.test", page.evaluate_script("document.activeElement.getAttribute('href')")
    assert page.evaluate_script("document.activeElement.matches(':focus-visible')")
    assert page.evaluate_script("parseFloat(getComputedStyle(document.activeElement).outlineWidth) >= 3")
    capture_system_screenshot("contact-the-post-long-details-390")

    commander.update!(ends_on: Organization.current_local_date - 1)
    visit people_path
    click_button "Menu"
    click_link "Contact the Post", exact: true
    assert_no_text "Morgan-Alexandra Reed-Worthington, Sr."
    assert_selector ".post-contact-name", count: 6
    assert_text "A current Commander is not listed yet."
    @organization.update!(public_email: nil, mailing_address: nil)
    PositionAssignment.update_all(ends_on: Organization.current_local_date - 1)
    visit post_contact_path
    assert_text "A general Post email has not been added yet."
    assert_text "Current officers have not been listed yet."
    assert_no_selector ".post-contact-page a[href^='mailto:']"
    assert_contact_layout
    capture_system_screenshot("contact-the-post-empty-390")
  end

  private

  def assert_contact_layout
    assert page.evaluate_script("document.documentElement.scrollWidth <= innerWidth"), "No horizontal page overflow"
    issues = page.evaluate_script(<<~JS)
      (() => {
        const content = document.querySelector('.post-contact-page');
        const links = [...content.querySelectorAll('a')];
        const issues = links.length ? [] : ['No contact or directory links found'];
        links.forEach(link => {
          const bounds = link.getBoundingClientRect();
          const style = getComputedStyle(link);
          if (bounds.height < 24 || bounds.left < 0 || bounds.right > innerWidth ||
              parseFloat(style.fontSize) < 16 || !style.textDecorationLine.includes('underline')) {
            issues.push({ text: link.textContent.trim(), height: bounds.height, left: bounds.left, right: bounds.right, fontSize: style.fontSize });
          }
        });
        content.querySelectorAll('.post-contact-details, .post-contact-office, .post-contact-note, .post-contact-responsibility, .post-contact-examples').forEach(element => {
          if (element.scrollWidth > element.clientWidth || parseFloat(getComputedStyle(element).fontSize) < 14) {
            issues.push({ className: element.className, problem: 'Text overflow or size' });
          }
        });
        return issues;
      })()
    JS
    assert_empty issues, "Contact links and text remain readable and inside the page"
  end
end
