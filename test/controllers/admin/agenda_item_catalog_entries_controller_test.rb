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

    # Rows have dedicated drag, move, and edit controls rather than nesting
    # controls inside a whole-row link.
    assert_select "[data-controller='catalog-reorder']"
    assert_select "[data-reorder-id=?] .pos-handle", active_entry.id.to_s
    assert_select "[data-reorder-id=?] a[href=?]", active_entry.id.to_s, edit_admin_agenda_item_catalog_entry_path(active_entry)
    assert_select "[data-reorder-id=?] button[aria-label=?]", active_entry.id.to_s, "Move Active Entry up"
    assert_select ".catalog-move-label", text: "Move"
    assert_select "[data-reorder-id=?][data-controller='confirm-dialog']", active_entry.id.to_s do
      assert_select "button.row-del[aria-label=?]", "Remove Active Entry"
      assert_select "dialog.confirm-dialog" do
        assert_select ".confirm-record-title", text: "Active Entry"
        assert_select "form[action=?] input[name='_method'][value='delete']", admin_agenda_item_catalog_entry_path(active_entry)
      end
    end

    # Inactive entries are flagged; active ones carry no status noise.
    assert_select "[data-reorder-id=?].mrow--inactive", inactive_entry.id.to_s
    assert_select "[data-reorder-id=?].mrow--inactive", active_entry.id.to_s, count: 0

    # Empty categories remain visible as cross-category drop destinations.
    assert_select "[data-category='memorial'] [data-catalog-reorder-target='list']"

    # Active status remains an edit-form choice rather than a noisy row action.
    assert_select "[data-reorder-id=?] button.row-del", active_entry.id.to_s, count: 1
  end

  test "reorder saves positions within and across categories" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    ceremony = create_entry(title: "Ceremony", category: "ceremony", position: 1)
    business_first = create_entry(title: "First Business", category: "business", position: 1)
    business_second = create_entry(title: "Second Business", category: "business", position: 2)

    post reorder_admin_agenda_item_catalog_entries_path, params: {
      categories: {
        ceremony: [ ceremony.id, business_second.id ],
        business: [ business_first.id ],
        reports: [], membership: [], memorial: [], administration: []
      }
    }, as: :json

    assert_response :success
    assert_equal [ [ "ceremony", 1 ], [ "ceremony", 2 ], [ "business", 1 ] ],
      [ ceremony, business_second, business_first ].map { |entry| entry.reload.slice(:category, :position).values }
  end

  test "reorder rejects foreign ids and changes nothing" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    entry = create_entry(title: "Post Item", category: "business", position: 4)
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    foreign = other.agenda_item_catalog_entries.create!(
      title: "Foreign", category: "business", behavior_type: "business_item", position: 1, active: true
    )

    post reorder_admin_agenda_item_catalog_entries_path, params: {
      categories: {
        ceremony: [], business: [ foreign.id ], reports: [], membership: [], memorial: [], administration: []
      }
    }, as: :json

    assert_response :unprocessable_entity
    assert_equal [ "business", 4 ], entry.reload.slice(:category, :position).values
  end

  test "reorder rejects unknown categories and changes nothing" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    entry = create_entry(title: "Post Item", category: "business", position: 4)

    post reorder_admin_agenda_item_catalog_entries_path, params: {
      categories: {
        ceremony: [], business: [ entry.id ], reports: [], membership: [], memorial: [], administration: [],
        unknown: []
      }
    }, as: :json

    assert_response :unprocessable_entity
    assert_equal [ "business", 4 ], entry.reload.slice(:category, :position).values
  end

  test "move down crosses into the next category" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    entry = create_entry(title: "Last Ceremony", category: "ceremony", position: 1)

    patch move_admin_agenda_item_catalog_entry_path(entry, direction: "down")

    assert_redirected_to admin_agenda_item_catalog_entries_path
    assert_equal "Agenda item moved.", flash[:notice]
    assert_equal [ "business", 1 ], entry.reload.slice(:category, :position).values
  end

  test "remove hides an entry without physically deleting it" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    entry = create_entry(title: "Local Ceremony", category: "ceremony", position: 30)

    assert_no_difference -> { @organization.agenda_item_catalog_entries.count } do
      delete admin_agenda_item_catalog_entry_path(entry)
    end

    assert_redirected_to admin_agenda_item_catalog_entries_path
    assert_equal "Agenda catalog item removed.", flash[:notice]
    assert_predicate entry.reload.removed_from_catalog_at, :present?
    assert_not @organization.agenda_item_catalog_entries.kept.exists?(entry.id)
  end

  test "cannot remove another organization entry" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    entry = other.agenda_item_catalog_entries.create!(
      title: "Other Entry", category: "business", behavior_type: "business_item", position: 1, active: true
    )

    delete admin_agenda_item_catalog_entry_path(entry)

    assert_response :not_found
    assert_nil entry.reload.removed_from_catalog_at
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
          body: "Discuss new business",
          commander_notes: "Pause for discussion.",
          show_wording_on_agenda: "0",
          show_wording_in_minutes: "0"
        }
      }
    end

    assert_redirected_to admin_agenda_item_catalog_entries_path
    assert_equal "Agenda item catalog entry created.", flash[:notice]
    entry = @organization.agenda_item_catalog_entries.find_by!(slug: "new-business")
    assert_equal 8, entry.position
    assert_equal "Discuss new business", entry.body.to_plain_text
    assert_equal "Pause for discussion.", entry.commander_notes.to_plain_text
    assert_not entry.show_wording_on_agenda?
    assert_not entry.show_wording_in_minutes?
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
    assert_select "lexxy-editor[name=?]", "agenda_item_catalog_entry[commander_notes]"
    assert_select "input[name=?][type='checkbox']", "agenda_item_catalog_entry[show_wording_on_agenda]"
    assert_select "input[name=?][type='checkbox']", "agenda_item_catalog_entry[show_wording_in_minutes]"
    assert_select "lexxy-editor[attachments=?]", "false", count: 2
    assert_select ".da-danger-zone[data-controller='confirm-dialog']" do
      assert_select "button[data-action='confirm-dialog#open']", text: "Remove catalog item"
      assert_select "dialog.confirm-dialog" do
        assert_select ".confirm-record-title", text: entry.title
        assert_select ".confirm-dialog-note", text: /Existing meeting templates and dated agendas will keep their copies/
        assert_select "form[action=?] input[name='_method'][value='delete']", admin_agenda_item_catalog_entry_path(entry)
      end
    end
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

  def create_entry(title:, category:, position:)
    @organization.agenda_item_catalog_entries.create!(
      title: title,
      category: category,
      behavior_type: "business_item",
      position: position,
      active: true
    )
  end

  def user_with_capabilities(*capabilities)
    person = Person.create!(first_name: "Test", last_name: "User")
    user = User.create!(person: person, email_address: "test-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end
end
