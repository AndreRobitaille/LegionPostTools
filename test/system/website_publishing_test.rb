require "application_system_test_case"
require_relative "../support/website_publishing_support"

class WebsitePublishingSystemTest < ApplicationSystemTestCase
  include WebsitePublishingSupport
  setup do
    setup_publisher
    Installation.singleton.update!(setup_completed_at: Time.current)
  end
  teardown { teardown_publisher }

  test "publisher reviews both portrait sizes consents publishes rotates and withdraws at phone width" do
    system_sign_in(@publisher)
    visit admin_website_publications_path
    click_button "Write an introduction"
    fill_in "Display name", with: "Avery (fictional)"
    fill_in "Introduction", with: "A synthetic introduction."
    fill_in "Story", with: "No real member is represented."
    fill_in "Portrait alt", with: "A synthetic test card"
    Tempfile.create([ "portrait", ".png" ]) do |file|
      file.binmode
      file.write(image_upload.read)
      file.flush
      attach_file "Portrait", file.path
      click_button "Save draft"
    end
    assert_text "Draft saved"
    assert_selector "img.publishing-portrait", count: 2
    click_button "Publish reviewed version"
    assert_text "Confirm consent for this exact text and portrait"
    fill_in "Consent record", with: "Synthetic fixture only"
    click_button "Record consent for this draft"
    assert_text "Consent recorded"
    page.driver.browser.manage.window.resize_to(390, 844)
    click_button "Publish reviewed version"
    assert_text "Published to the public website"
    assert_selector "img.publishing-portrait", count: 3
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, 390
    visit admin_website_publications_path
    select "Avery (fictional)", from: "Introduction 1"
    click_button "Update homepage order"
    assert_text "Homepage introductions updated"
    click_link "Avery (fictional)"
    click_button "Revoke consent and withdraw"
    assert_text "Withdrawn from the public website"
    assert_text "This introduction is not currently public"
    assert_nil WebsitePublication.find_by!(kind: "story").featured_position
  end
end
