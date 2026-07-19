require "test_helper"

class Admin::DatedAgendasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.first || Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    @organization.update!(name: "Robert E. Burns Post 165", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @meeting_body = @organization.meeting_bodies.first || @organization.meeting_bodies.create!(name: "Membership", slug: "membership-#{SecureRandom.hex(4)}")
    @meeting_type = @organization.meeting_types.first || @organization.meeting_types.create!(name: "Membership Meeting", slug: "membership-meeting-#{SecureRandom.hex(4)}", position: 1, active: true)
    @catalog_entry = @organization.agenda_item_catalog_entries.first || @organization.agenda_item_catalog_entries.create!(title: "Opening Ceremony", slug: "opening-ceremony-#{SecureRandom.hex(4)}", category: "ceremony", behavior_type: "scripted_ceremony", position: 1, active: true, body: "Opening words")
    @meeting_type.meeting_type_agenda_items.find_or_create_by!(agenda_item_catalog_entry: @catalog_entry) do |item|
      item.position = 1
      item.title = "Opening"
      item.active = true
      item.body = "Template body"
    end
    @agenda = DatedAgenda.create_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))
  end

  test "signed out users are redirected" do
    get admin_dated_agendas_path

    assert_redirected_to new_session_path
  end

  test "users without manage_agendas are denied" do
    sign_in_as(user_with_capabilities)

    get admin_dated_agendas_path

    assert_redirected_to root_path
    assert_equal "You do not have permission to open that page.", flash[:alert]
  end

  test "users without manage_agendas cannot access print" do
    sign_in_as(user_with_capabilities)
    agenda = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.parse("2026-08-04 19:00"), title: "Membership Meeting — August 4, 2026", status: "draft")

    get print_admin_dated_agenda_path(agenda)

    assert_redirected_to root_path
    assert_equal "You do not have permission to open that page.", flash[:alert]
  end

  test "index lists dated agendas" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    existing = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.parse("2026-08-04 19:00"), title: "Membership Meeting — August 4, 2026", status: "draft")

    get admin_dated_agendas_path

    assert_response :success
    assert_select "h1", text: /Dated Agendas/
    assert_select "a[href=?]", new_admin_dated_agenda_path, text: /New Dated Agenda/i
    assert_select "body", text: /Membership/
  end

  test "index renders agendas in the design system with a status tag and house date format" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    get admin_dated_agendas_path

    assert_response :success
    assert_select ".page-lead .page-title", text: "Dated Agendas"
    assert_select ".mrow-list .mrow.catrow .mrow-name"
    assert_select ".mrow-list .catrow-meta .st"
    assert_select "a.btn-primary", text: "New dated agenda"
  end

  test "new form includes dated agenda fields" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    get new_admin_dated_agenda_path

    assert_response :success
    assert_select "select[name=?]", "dated_agenda[meeting_body_id]"
    assert_select "select[name=?]", "dated_agenda[meeting_type_id]"
    assert_select "input[name=?]", "dated_agenda[starts_at]"
    assert_select "input[name=?]", "dated_agenda[title]"
  end

  test "new renders a stacked form with plain labels and a title field" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    get new_admin_dated_agenda_path

    assert_response :success
    assert_select "form.stacked-form"
    assert_select "form.stacked-form select[name='dated_agenda[meeting_body_id]']"
    assert_select "form.stacked-form select[name='dated_agenda[meeting_type_id]']"
    assert_select "form.stacked-form input[name='dated_agenda[starts_at]']"
    assert_select "form.stacked-form input.btn-primary"
  end

  test "create copies meeting type agenda items" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    assert_difference -> { DatedAgenda.where(organization_id: @organization.id).count }, 1 do
      post admin_dated_agendas_path, params: { dated_agenda: { meeting_body_id: @meeting_body.id, meeting_type_id: @meeting_type.id, starts_at: "2026-08-04T19:00", title: "" } }
    end

    agenda = DatedAgenda.where(organization_id: @organization.id).order(:created_at).last
    assert_redirected_to edit_admin_dated_agenda_path(agenda)
    assert_equal "Dated agenda created.", flash[:notice]
    assert_equal "Membership Meeting — 04 AUG 2026", agenda.title
    assert_equal 1, agenda.dated_agenda_items.count
    assert_equal [ "Opening" ], agenda.dated_agenda_items.order(:position).pluck(:title)
  end

  test "create rejects another organization's meeting type" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    other_suffix = SecureRandom.hex(4)
    other_body = other.meeting_bodies.create!(name: "Membership", slug: "membership-#{other_suffix}")
    other_type = other.meeting_types.create!(name: "Membership Meeting", slug: "membership-meeting-#{other_suffix}", position: 1, active: true)

    post admin_dated_agendas_path, params: { dated_agenda: { meeting_body_id: @meeting_body.id, meeting_type_id: other_type.id, starts_at: "2026-08-04T19:00", title: "" } }

    assert_response :not_found
  end

  test "create rejects inactive meeting types" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    inactive = @organization.meeting_types.create!(name: "Inactive Meeting", slug: "inactive-meeting-#{SecureRandom.hex(4)}", position: 2, active: false)

    post admin_dated_agendas_path, params: { dated_agenda: { meeting_body_id: @meeting_body.id, meeting_type_id: inactive.id, starts_at: "2026-08-04T19:00", title: "" } }

    assert_response :not_found
  end

  test "update does not retarget meeting body or meeting type" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    agenda = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.parse("2026-08-04 19:00"), title: "Membership Meeting — August 4, 2026", status: "draft")
    other_body = @organization.meeting_bodies.create!(name: "Other Body", slug: "other-body-#{SecureRandom.hex(4)}")
    other_type = @organization.meeting_types.create!(name: "Other Type", slug: "other-type-#{SecureRandom.hex(4)}", position: 2, active: true)

    patch admin_dated_agenda_path(agenda), params: { dated_agenda: { meeting_body_id: other_body.id, meeting_type_id: other_type.id, starts_at: "2026-08-11T19:00", title: "Updated Title" } }

    assert_redirected_to edit_admin_dated_agenda_path(agenda)
    assert_equal @meeting_body.id, agenda.reload.meeting_body_id
    assert_equal @meeting_type.id, agenda.meeting_type_id
    assert_equal "Updated Title", agenda.title
    assert_equal Time.zone.parse("2026-08-11 19:00"), agenda.starts_at
  end

  test "approve locks agenda and records approver" do
    user = user_with_capabilities("manage_agendas")
    sign_in_as(user)
    agenda = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.parse("2026-08-04 19:00"), title: "Membership Meeting — August 4, 2026", status: "draft")

    patch approve_admin_dated_agenda_path(agenda)

    assert_redirected_to edit_admin_dated_agenda_path(agenda)
    assert_equal "Dated agenda approved.", flash[:notice]
    assert_equal "approved", agenda.reload.status
    assert_equal user, agenda.approved_by
    assert_not_nil agenda.approved_at
  end

  test "publish requires approved agenda" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    agenda = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.parse("2026-08-04 19:00"), title: "Membership Meeting — August 4, 2026", status: "draft")

    patch publish_admin_dated_agenda_path(agenda)

    assert_redirected_to edit_admin_dated_agenda_path(agenda)
    assert_equal "Approve this agenda before publishing it.", flash[:alert]
    assert_equal "draft", agenda.reload.status
  end

  test "reopen returns approved agenda to draft" do
    user = user_with_capabilities("manage_agendas")
    sign_in_as(user)
    agenda = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.parse("2026-08-04 19:00"), title: "Membership Meeting — August 4, 2026", status: "approved", approved_by: user, approved_at: Time.current)

    patch reopen_admin_dated_agenda_path(agenda)

    assert_redirected_to edit_admin_dated_agenda_path(agenda)
    assert_equal "Dated agenda reopened.", flash[:notice]
    assert_equal "draft", agenda.reload.status
    assert_nil agenda.approved_by
  end

  test "second approve redirects with alert" do
    user = user_with_capabilities("manage_agendas")
    sign_in_as(user)
    agenda = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.parse("2026-08-04 19:00"), title: "Membership Meeting — August 4, 2026", status: "draft")

    patch approve_admin_dated_agenda_path(agenda)
    patch approve_admin_dated_agenda_path(agenda)

    assert_redirected_to edit_admin_dated_agenda_path(agenda)
    assert_equal "Only draft agendas can be approved.", flash[:alert]
    assert_equal "approved", agenda.reload.status
    assert_equal user, agenda.approved_by
  end

  test "second publish redirects with alert" do
    user = user_with_capabilities("manage_agendas")
    sign_in_as(user)
    agenda = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.parse("2026-08-04 19:00"), title: "Membership Meeting — August 4, 2026", status: "draft")

    patch approve_admin_dated_agenda_path(agenda)
    patch publish_admin_dated_agenda_path(agenda)
    patch publish_admin_dated_agenda_path(agenda)

    assert_redirected_to edit_admin_dated_agenda_path(agenda)
    assert_equal "Approve this agenda before publishing it.", flash[:alert]
    assert_equal "published", agenda.reload.status
    assert_equal user, agenda.published_by
  end

  test "reopen from draft redirects with alert" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    agenda = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.parse("2026-08-04 19:00"), title: "Membership Meeting — August 4, 2026", status: "draft")

    patch reopen_admin_dated_agenda_path(agenda)

    assert_redirected_to edit_admin_dated_agenda_path(agenda)
    assert_equal "Only approved or published agendas can be reopened.", flash[:alert]
    assert_equal "draft", agenda.reload.status
  end

  test "stale agenda update redirects with conflict message" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    agenda = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.parse("2026-08-04 19:00"), title: "Membership Meeting — August 4, 2026", status: "draft")
    stale_lock_version = agenda.lock_version
    agenda.update!(title: "Changed elsewhere")

    patch admin_dated_agenda_path(agenda), params: { dated_agenda: { starts_at: "2026-08-04T19:00", title: "Stale", lock_version: stale_lock_version } }

    assert_redirected_to edit_admin_dated_agenda_path(agenda)
    assert_equal "This agenda was changed by someone else. Review the latest version before saving.", flash[:alert]
  end

  test "reopen controls use current_user lifecycle flow" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    agenda = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.parse("2026-08-04 19:00"), title: "Membership Meeting — August 4, 2026", status: "approved")

    get edit_admin_dated_agenda_path(agenda)

    assert_response :success
    assert_select "button", text: "Reopen for editing"
    assert_select "button[data-turbo-confirm=?]", "Reopen this approved agenda for editing?"
  end

  test "edit page shows print link" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    agenda = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.parse("2026-08-04 19:00"), title: "Membership Meeting — August 4, 2026", status: "draft")

    get edit_admin_dated_agenda_path(agenda)

    assert_response :success
    assert_select "a[href=?]", print_admin_dated_agenda_path(agenda), text: "Print"
  end

  test "print view renders agenda details without edit controls" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    agenda = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.parse("2026-08-04 19:00"), title: "Membership Meeting — August 4, 2026", status: "draft")

    get print_admin_dated_agenda_path(agenda)

    assert_response :success
    assert_select "h1.page-title", text: "Membership Meeting — August 4, 2026"
    assert_select "body", text: /Membership Meeting/
    assert_select "a[href=?]", edit_admin_dated_agenda_path(agenda), count: 0
    assert_select "form[action=?]", approve_admin_dated_agenda_path(agenda), count: 0
    assert_select "nav", count: 0
    assert_select "body", text: "Dashboard", count: 0
  end

  test "admin print renders a chrome-free agenda document" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    get print_admin_dated_agenda_path(@agenda)

    assert_response :success
    assert_select "article.agenda-doc .agenda-masthead .page-title", text: @agenda.title
    assert_select ".agenda-item .agenda-item-title"
    assert_select "a.back", false
    assert_select ".btnrow", false
  end

  test "empty template create shows empty state guidance" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    empty_type = @organization.meeting_types.create!(name: "Empty Meeting", slug: "empty-meeting-#{SecureRandom.hex(4)}", position: 2, active: true)

    post admin_dated_agendas_path, params: { dated_agenda: { meeting_body_id: @meeting_body.id, meeting_type_id: empty_type.id, starts_at: "2026-08-04T19:00", title: "" } }

    agenda = DatedAgenda.where(organization_id: @organization.id, meeting_type_id: empty_type.id).order(:created_at).last
    get edit_admin_dated_agenda_path(agenda)

    assert_response :success
    assert_select "body", text: /This agenda does not have any items yet. Add items from the catalog to build this meeting agenda./
  end

  test "failed template copy rolls back dated agenda creation" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    original_create = DatedAgendaItem.method(:create!)
    DatedAgendaItem.define_singleton_method(:create!, ->(*) { raise StandardError, "copy failed" })

    assert_no_difference -> { DatedAgenda.where(organization_id: @organization.id).count } do
      assert_raises(StandardError) do
        post admin_dated_agendas_path, params: { dated_agenda: { meeting_body_id: @meeting_body.id, meeting_type_id: @meeting_type.id, starts_at: "2026-08-04T19:00", title: "" } }
      end
    end
  ensure
    DatedAgendaItem.define_singleton_method(:create!, &original_create)
  end

  test "invalid starts_at renders new form with error" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    post admin_dated_agendas_path, params: { dated_agenda: { meeting_body_id: @meeting_body.id, meeting_type_id: @meeting_type.id, starts_at: "", title: "" } }

    assert_response :unprocessable_entity
    assert_select ".error-summary", text: /Starts at can't be blank/
  end

  test "edit shows the lifecycle bar, drag-reorder list, and Approve for a draft" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    get edit_admin_dated_agenda_path(@agenda)

    assert_response :success
    assert_select ".da-lifecycle .st.st--draft"
    assert_select "form[action='#{approve_admin_dated_agenda_path(@agenda)}']"
    assert_select "[data-controller='reorder'][data-reorder-url-value='#{reorder_admin_dated_agenda_agenda_items_path(@agenda)}']"
    assert_select ".mrow-list[data-reorder-target='list'] .mrow.catrow[data-reorder-item] .pos-handle"
    assert_select ".mrow.catrow .catrow-meta button.row-del"
  end

  test "edit locks the item list and shows Publish + Reopen when approved" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    @agenda.approve!(User.last)

    get edit_admin_dated_agenda_path(@agenda)

    assert_response :success
    assert_select ".da-lifecycle .st.st--approved"
    assert_select "form[action='#{publish_admin_dated_agenda_path(@agenda)}']"
    assert_select "form[action='#{reopen_admin_dated_agenda_path(@agenda)}']"
    assert_select ".readonly-tip"
    assert_select "[data-controller='reorder']", false
    assert_select ".pos-handle", false
    assert_select "button.row-del", false
    assert_select "input[name='dated_agenda[starts_at]']", false
    assert_select "input[name='dated_agenda[title]']", false
  end

  private

  def user_with_capabilities(*capabilities)
    person = Person.create!(first_name: "Test", last_name: "User")
    user = User.create!(person: person, email_address: "test-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end
end
