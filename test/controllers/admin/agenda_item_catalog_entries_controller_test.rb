require "test_helper"

class Admin::AgendaItemCatalogEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  test "signed out users are redirected" do
    get admin_agenda_item_catalog_entries_path

    assert_redirected_to new_session_path
  end

  test "users without manage_agendas are denied" do
    sign_in_as(user_with_capabilities)

    get admin_agenda_item_catalog_entries_path

    assert_redirected_to root_path
    assert_equal "You do not have permission to open that page.", flash[:alert]
  end

  test "index seeds and lists entries for agenda managers" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    active_entry = @organization.agenda_item_catalog_entries.create!(
      title: "Active Entry",
      slug: "active-entry",
      summary: "Active",
      category: "business",
      behavior_type: "business_item",
      position: 10,
      active: true
    )
    inactive_entry = @organization.agenda_item_catalog_entries.create!(
      title: "Inactive Entry",
      slug: "inactive-entry",
      summary: "Inactive",
      category: "business",
      behavior_type: "business_item",
      position: 11,
      active: false
    )

    get admin_agenda_item_catalog_entries_path

    assert_response :success
    assert_select "h1", text: /Agenda Item Catalog/
    assert_select "body", text: /Opening Ceremony/
    assert_select "a.back[href=?]", root_path, text: /Dashboard/
    assert_select "a.back[href=?]", admin_root_path, count: 0

    # Rows are click-to-open links straight to the edit page.
    assert_select "a.mrow[href=?]", edit_admin_agenda_item_catalog_entry_path(active_entry)
    assert_select "a.mrow[href=?]", edit_admin_agenda_item_catalog_entry_path(inactive_entry)

    # Inactive entries are flagged; active ones carry no status noise.
    assert_select "a.mrow.mrow--inactive[href=?]", edit_admin_agenda_item_catalog_entry_path(inactive_entry)
    assert_select "a.mrow.mrow--inactive[href=?]", edit_admin_agenda_item_catalog_entry_path(active_entry), count: 0

    # No per-row deactivate/reactivate controls remain on the index.
    assert_select "form[action=?]", admin_agenda_item_catalog_entry_path(active_entry), count: 0
  end

  test "index back link points to administration for manage_settings users" do
    sign_in_as(user_with_capabilities("manage_agendas", "manage_settings"))

    get admin_agenda_item_catalog_entries_path

    assert_response :success
    assert_select "a.back[href=?]", admin_root_path, text: /Administration/
  end

  test "create entry" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    @organization.agenda_item_catalog_entries.create!(
      title: "Existing Business",
      category: "business",
      behavior_type: "business_item",
      position: 7,
      active: true
    )

    assert_difference -> { @organization.agenda_item_catalog_entries.count }, 1 do
      post admin_agenda_item_catalog_entries_path, params: {
        agenda_item_catalog_entry: {
          title: "New Business",
          summary: "Add new business",
          category: "business",
          behavior_type: "business_item",
          active: true,
          body: "Discuss new business"
        }
      }
    end

    assert_redirected_to admin_agenda_item_catalog_entries_path
    assert_equal "Agenda item catalog entry created.", flash[:notice]
    entry = @organization.agenda_item_catalog_entries.find_by!(slug: "new-business")
    assert_equal 8, entry.position
    assert_equal "Discuss new business", entry.body.to_plain_text
  end

  test "invalid create returns unprocessable entity with error summary" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    post admin_agenda_item_catalog_entries_path, params: {
      agenda_item_catalog_entry: {
        title: "",
        summary: "",
        category: "",
        behavior_type: "business_item",
        active: true,
        body: ""
      }
    }

    assert_response :unprocessable_entity
    assert_select ".error-summary", text: /Title can't be blank/
    assert_select ".error-summary", text: /Category can't be blank/
  end

  test "update entry rich text and active flag" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    entry = @organization.agenda_item_catalog_entries.create!(
      title: "Previous Minutes",
      slug: "previous-minutes",
      summary: "Read minutes",
      category: "administration",
      behavior_type: "motion_vote_item",
      position: 1,
      active: true,
      body: "Old body"
    )

    patch admin_agenda_item_catalog_entry_path(entry), params: {
      agenda_item_catalog_entry: {
        title: "Updated Minutes",
        summary: "Read and approve minutes",
        category: "administration",
        behavior_type: "motion_vote_item",
        active: false,
        body: "New body"
      }
    }

    assert_redirected_to admin_agenda_item_catalog_entries_path
    assert_equal "Agenda item catalog entry updated.", flash[:notice]
    assert_equal "Updated Minutes", entry.reload.title
    assert_not entry.reload.active
    assert_equal "New body", entry.body.to_plain_text
  end

  test "invalid update returns unprocessable entity with error summary" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    entry = @organization.agenda_item_catalog_entries.create!(
      title: "Previous Minutes",
      slug: "previous-minutes",
      summary: "Read minutes",
      category: "administration",
      behavior_type: "motion_vote_item",
      position: 1,
      active: true,
      body: "Old body"
    )

    patch admin_agenda_item_catalog_entry_path(entry), params: {
      agenda_item_catalog_entry: {
        title: "",
        summary: "",
        category: "",
        behavior_type: "motion_vote_item",
        active: false,
        body: ""
      }
    }

    assert_response :unprocessable_entity
    assert_select ".error-summary", text: /Title can't be blank/
    assert_select ".error-summary", text: /Category can't be blank/
  end

  test "edit form hides developer fields and keeps officer-facing ones" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    entry = @organization.agenda_item_catalog_entries.create!(
      title: "Opening Ceremony",
      slug: "opening-ceremony",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      position: 1,
      active: true
    )

    get edit_admin_agenda_item_catalog_entry_path(entry)

    assert_response :success
    assert_select "input[name=?]", "agenda_item_catalog_entry[slug]", count: 0
    assert_select "input[name=?]", "agenda_item_catalog_entry[position]", count: 0
    assert_select "input[name=?]", "agenda_item_catalog_entry[title]"
    assert_select "select[name=?]", "agenda_item_catalog_entry[category]"
    assert_select "textarea[name=?]", "agenda_item_catalog_entry[summary]"
    assert_select "lexxy-editor[name=?]", "agenda_item_catalog_entry[body]"
    assert_select "lexxy-editor[attachments=?]", "false"
  end

  test "cannot edit another organization entry" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    entry = other.agenda_item_catalog_entries.create!(
      title: "Other Entry",
      slug: "other-entry",
      summary: "Other",
      category: "business",
      behavior_type: "business_item",
      position: 1,
      active: true
    )

    get edit_admin_agenda_item_catalog_entry_path(entry)

    assert_response :not_found
  end

  private

  def user_with_capabilities(*capabilities)
    person = Person.create!(first_name: "Test", last_name: "User")
    user = User.create!(person: person, email_address: "test-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end
end
