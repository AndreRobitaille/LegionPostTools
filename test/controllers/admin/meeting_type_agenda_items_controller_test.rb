require "test_helper"

class Admin::MeetingTypeAgendaItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    @other_organization = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    @catalog_entry = @organization.agenda_item_catalog_entries.create!(title: "Opening Ceremony", category: "ceremony", behavior_type: "scripted_ceremony", position: 1, active: true, body: "Welcome")
    @inactive_entry = @organization.agenda_item_catalog_entries.create!(title: "Inactive Ceremony", category: "ceremony", behavior_type: "scripted_ceremony", position: 2, active: false)
    @other_entry = @other_organization.agenda_item_catalog_entries.create!(title: "Other Entry", category: "ceremony", behavior_type: "scripted_ceremony", position: 1, active: true)
  end

  test "picker requires manage_agendas" do
    sign_in_as(user_with_capabilities)

    get new_admin_meeting_type_agenda_item_path(@meeting_type)

    assert_redirected_to root_path
  end

  test "picker lists active catalog entries and excludes inactive entries" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    get new_admin_meeting_type_agenda_item_path(@meeting_type)

    assert_response :success
    assert_select "body", text: /Opening Ceremony/
    assert_select "body", text: /Inactive Ceremony/, count: 0
  end

  test "add catalog item copies it into meeting type with rich body" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    assert_difference -> { @meeting_type.meeting_type_agenda_items.count }, 1 do
      post admin_meeting_type_agenda_items_path(@meeting_type), params: { agenda_item_catalog_entry_id: @catalog_entry.id }
    end

    item = @meeting_type.meeting_type_agenda_items.last
    assert_equal @catalog_entry.title, item.title
    assert_includes item.body.to_s, "Welcome"
    assert_redirected_to edit_admin_meeting_type_path(@meeting_type)
    assert_equal "Catalog item added.", flash[:notice]
  end

  test "duplicate add is rejected" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: @catalog_entry, position: 1, title: @catalog_entry.title, active: true)

    assert_no_difference -> { @meeting_type.meeting_type_agenda_items.count } do
      post admin_meeting_type_agenda_items_path(@meeting_type), params: { agenda_item_catalog_entry_id: @catalog_entry.id }
    end

    assert_redirected_to new_admin_meeting_type_agenda_item_path(@meeting_type)
    assert_equal "That catalog item is already in this meeting type.", flash[:alert]
  end

  test "update template item does not change catalog entry" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    item = @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: @catalog_entry, position: 1, title: "Old", summary: "Old summary", active: true, body: "Old body")

    patch admin_meeting_type_agenda_item_path(@meeting_type, item), params: { meeting_type_agenda_item: { title: "New", summary: "New summary", active: false, body: "New body" } }

    assert_redirected_to edit_admin_meeting_type_path(@meeting_type)
    assert_equal "Template item updated.", flash[:notice]
    assert_equal "New", item.reload.title
    assert_not item.active?
    assert_includes item.body.to_s, "New body"
    assert_equal @catalog_entry.title, @catalog_entry.reload.title
  end

  test "move item up and down swaps positions" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    first = @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: @catalog_entry, position: 1, title: "First", active: true)
    second_entry = @organization.agenda_item_catalog_entries.create!(title: "Second Entry", category: "ceremony", behavior_type: "scripted_ceremony", position: 3, active: true)
    second = @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: second_entry, position: 2, title: "Second", active: true)

    patch move_admin_meeting_type_agenda_item_path(@meeting_type, second, direction: "up")
    assert_equal [ 2, 1 ], [ first.reload.position, second.reload.position ]

    patch move_admin_meeting_type_agenda_item_path(@meeting_type, second, direction: "down")
    assert_equal [ 1, 2 ], [ first.reload.position, second.reload.position ]
  end

  test "remove deletes only template item and leaves catalog entry" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    item = @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: @catalog_entry, position: 1, title: @catalog_entry.title, active: true)

    assert_difference -> { @meeting_type.meeting_type_agenda_items.count }, -1 do
      delete admin_meeting_type_agenda_item_path(@meeting_type, item)
    end

    assert_equal 2, @organization.agenda_item_catalog_entries.count
    assert_redirected_to edit_admin_meeting_type_path(@meeting_type)
    assert_equal "Template item removed.", flash[:notice]
  end

  test "edit form renders editable template fields" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    item = @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: @catalog_entry, position: 1, title: "Opening Ceremony", summary: "Read the opening script.", active: true, body: "Welcome")

    get edit_admin_meeting_type_agenda_item_path(@meeting_type, item)

    assert_response :success
    assert_select "input[name='meeting_type_agenda_item[title]']"
    assert_select "textarea[name='meeting_type_agenda_item[summary]']"
    assert_select "lexxy-editor[input='meeting_type_agenda_item_body_trix_input_meeting_type_agenda_item_#{item.id}']"
    assert_select "input[name='meeting_type_agenda_item[active]'][type='checkbox']"
    assert_select "body", text: /source_key/i, count: 0
    assert_select "body", text: /source_label/i, count: 0
    assert_select "body", text: /catalog entry/i, count: 0
    assert_select "body", text: /developer/i, count: 0
  end

  test "cannot use another organization's catalog entry or meeting type" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    other_meeting_type = @other_organization.meeting_types.create!(name: "Other", position: 1, active: true)

    get new_admin_meeting_type_agenda_item_path(other_meeting_type)
    assert_response :not_found

    post admin_meeting_type_agenda_items_path(@meeting_type), params: { agenda_item_catalog_entry_id: @other_entry.id }
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
