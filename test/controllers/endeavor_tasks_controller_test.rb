require "test_helper"

class EndeavorTasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Example Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @manager = User.create!(person: Person.create!(first_name: "Project", last_name: "Manager"), email_address: "task-manager@example.com")
    @manager.permission_grants.create!(capability: "manage_agendas")
    @member = User.create!(person: Person.create!(first_name: "Post", last_name: "Member"), email_address: "task-member@example.com")
    @endeavor = @organization.endeavors.create!(title: "Newsletter", created_by: @manager)
    @task = @endeavor.tasks.create!(title: "Collect articles", due_on: Date.current + 3.days, created_by: @manager, updated_by: @manager)
  end

  test "members can read next steps but cannot create or change them" do
    sign_in_as(@member)
    get endeavor_path(@endeavor)
    assert_response :success
    assert_select "#endeavor-next-steps", text: /Collect articles/
    assert_select "a[href=?]", new_endeavor_task_path(@endeavor), count: 0
    get new_endeavor_task_path(@endeavor)
    assert_redirected_to root_path
    assert_no_difference "EndeavorTask.count" do
      post endeavor_tasks_path(@endeavor), params: { endeavor_task: { title: "Not permitted" } }
      assert_redirected_to root_path
    end
    patch endeavor_task_path(@endeavor, @task), params: { endeavor_task: { title: "Not permitted" } }
    assert_redirected_to root_path
    assert_equal "Collect articles", @task.reload.title
  end

  test "manager creates dated and undated steps without creating calendar events" do
    sign_in_as(@manager)
    get new_endeavor_task_path(@endeavor)
    assert_response :success
    assert_no_difference "CalendarEvent.count" do
      [ "15 SEP 2026", "" ].each do |date|
        assert_difference "EndeavorTask.count", 1 do
          post endeavor_tasks_path(@endeavor), params: { endeavor_task: { title: "Print newsletter", due_on: date } }
        end
        assert_redirected_to endeavor_path(@endeavor, anchor: "endeavor-next-steps")
      end
    end
    assert_nil @endeavor.tasks.order(:id).last.due_on
  end

  test "completion and reopening preserve the next step and record provenance" do
    sign_in_as(@manager)
    get edit_endeavor_task_path(@endeavor, @task)
    assert_response :success
    patch endeavor_task_path(@endeavor, @task), params: { endeavor_task: { completed: "1", lock_version: @task.lock_version } }
    assert @task.reload.completed?
    assert_equal @manager, @task.completed_by
    original_completion = @task.completed_at
    patch endeavor_task_path(@endeavor, @task), params: { endeavor_task: { completed: "1", lock_version: @task.lock_version } }
    assert_equal original_completion, @task.reload.completed_at
    patch endeavor_task_path(@endeavor, @task), params: { endeavor_task: { completed: "0", lock_version: @task.lock_version } }
    assert_not @task.reload.completed?
    assert_nil @task.completed_by
    assert_equal @manager, @task.updated_by
  end

  test "invalid date remains in the form and does not save" do
    sign_in_as(@manager)
    assert_no_difference "EndeavorTask.count" do
      post endeavor_tasks_path(@endeavor), params: { endeavor_task: { title: "Print", due_on: "not a date" } }
    end
    assert_response :unprocessable_entity
    assert_select "input[name='endeavor_task[due_on]'][value='not a date']"
  end

  test "stale completion cannot overwrite an edited step" do
    sign_in_as(@manager)
    old = @task.lock_version
    @task.update!(title: "Collect photos and articles")
    patch endeavor_task_path(@endeavor, @task), params: { endeavor_task: { completed: "1", lock_version: old } }
    assert_redirected_to endeavor_path(@endeavor, anchor: "endeavor-next-steps")
    assert_not @task.reload.completed?
    assert_equal "Collect photos and articles", @task.title
  end

  test "task lookup is scoped to its Endeavor" do
    other = @organization.endeavors.create!(title: "Car show", created_by: @manager)
    sign_in_as(@manager)
    patch endeavor_task_path(other, @task), params: { endeavor_task: { title: "Wrong project" } }
    assert_response :not_found
    assert_equal "Collect articles", @task.reload.title
  end

  test "overall due date supports new terminology and preserves legacy storage" do
    sign_in_as(@manager)
    patch endeavor_path(@endeavor), params: { endeavor: { due_on: "20 SEP 2026", lock_version: @endeavor.lock_version } }
    assert_redirected_to endeavor_path(@endeavor)
    assert_equal Date.new(2026, 9, 20), @endeavor.reload.due_on
    assert_equal @endeavor.due_on, @endeavor.raise_by_on
    get edit_endeavor_path(@endeavor)
    assert_select "label", text: "Overall due date (optional)"
    assert_select "label", text: "Raise by", count: 0
    patch endeavor_path(@endeavor), params: { endeavor: { due_on: "bad date", lock_version: @endeavor.lock_version } }
    assert_response :unprocessable_entity
    assert_equal Date.new(2026, 9, 20), @endeavor.reload.due_on
  end
end
