require_relative "buddy_authority_fixture"

# Additional recipient only; never resets or rewrites the consumed authority cases.
class BuddyReminderFixture
  ZONE = "America/Chicago"
  INITIAL_DUE = "2026-10-13T20:00:00Z"
  RESCHEDULED_DUE = "2026-10-13T21:00:00Z"
  ACTIONS = %w[reminder_reschedule reminder_complete].freeze

  def initialize
    raise "Exact reminder acceptance database required" unless Rails.env.test? && ActiveRecord::Base.connection_db_config.database == "legion_buddy_authority_test"
    fixture = BuddyAuthorityFixture.new.fixture
    raise "Exact authority issuer required" unless fixture.fetch("issuer") == "https://192.168.37.41:3444"
    @organization = Organization.find(fixture.fetch("organization_id"))
    @caller = User.find(fixture.fetch("caller_id"))
    raise "Synthetic Jamie required" unless @caller.email_address == "jamie@example.test"
    @operations = BuddyChecks::Operations.new(BuddyChecks::Access.new(user: @caller, organization: @organization))
    @directory = File.dirname(ENV.fetch("BUDDY_MOBILE_FIXTURE_FILE"))
    @plan_path = File.join(@directory, "reminder.json")
  end

  def setup!
    locked do
      raise "Reminder plan already exists; inspect status, never reset" if File.exist?(@plan_path)
      raise "Quinn or follow-up evidence already exists" if Person.where(first_name: "Quinn", last_name: "Reminder").exists? || BuddyFollowUp.exists?
      raise "Initial due time is no longer in the future" unless Time.iso8601(INITIAL_DUE) > Time.current
      plan = { entry_zone: ZONE, initial_due_at: INITIAL_DUE, rescheduled_due_at: RESCHEDULED_DUE,
        operation_ids: %w[schedule reminder_reschedule reminder_complete].index_with { SecureRandom.uuid } }
      # Persist operation identities before any DB write, for reconciliation after interruption.
      File.open(@plan_path, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
        file.write(JSON.pretty_generate(plan))
        file.flush
        file.fsync
      end
      ApplicationRecord.transaction do
        person = Person.create!(first_name: "Quinn", last_name: "Reminder", member_number: "000000000006",
          roster_member_status: "Active", roster_paid_through_year: 2026, roster_imported_at: Time.current,
          roster_phone_number: "+1-202-555-0205", roster_email_address: "quinn@example.test")
        @operations.schedule(operation_id: plan.fetch(:operation_ids).fetch("schedule"), person_id: person.id,
          due_at: INITIAL_DUE, entry_zone: ZONE)
      end
      result = status
      journal!("setup", "Explicitly approved independent Quinn reminder; no native checkpoint advanced", nil, result)
      result
    end
  end

  def status
    plan = read_plan
    scheduled = @operations.receipt(plan.fetch("operation_ids").fetch("schedule")).fetch("follow_up")
    follow_up = BuddyFollowUp.find(scheduled.fetch("id"))
    person = follow_up.person
    raise "Reminder identity drift" unless follow_up.organization_id == @organization.id && follow_up.user_id == @caller.id &&
      follow_up.membership_contact_id.nil? && person.first_name == "Quinn" && person.last_name == "Reminder"
    raise "Quinn has unexpected contact evidence" if MembershipContact.where(person:).exists?
    { database: ActiveRecord::Base.connection_db_config.database, user_id: @caller.id, person_id: person.id,
      follow_up: @operations.follow_up_payload(follow_up), initial_due_at: plan.fetch("initial_due_at"),
      rescheduled_due_at: plan.fetch("rescheduled_due_at"), operation_ids: plan.fetch("operation_ids"),
      receipt_ids: plan.fetch("operation_ids").transform_values { |id| BuddyOperation.find_by(operation_id: id, user: @caller)&.id },
      contacts: MembershipContact.count, receipts: BuddyOperation.count, follow_ups: BuddyFollowUp.count }
  end

  def advance!(action, checkpoint:)
    raise "Known action and actual native checkpoint required" unless ACTIONS.include?(action) && checkpoint.to_s.strip.length.between?(8, 500)
    locked do
      plan = read_plan
      before = status
      expected_revision = action == "reminder_reschedule" ? 0 : 1
      expected_due = action == "reminder_reschedule" ? plan.fetch("initial_due_at") : plan.fetch("rescheduled_due_at")
      current = before.fetch(:follow_up)
      raise "Reminder state drift; inspect evidence" unless current[:status] == "open" && current[:revision] == expected_revision &&
        Time.iso8601(current[:due_at]) == Time.iso8601(expected_due) && current[:entry_zone] == ZONE
      operation_id = plan.fetch("operation_ids").fetch(action)
      raise "Checkpoint operation already accepted; inspect its receipt" if BuddyOperation.where(operation_id:).exists?
      if action == "reminder_complete"
        rescheduled = @operations.receipt(plan.fetch("operation_ids").fetch("reminder_reschedule")).fetch("follow_up")
        raise "Missing matching reschedule evidence" unless rescheduled.fetch("id") == current[:id] && rescheduled.fetch("revision") == 1
      end
      attributes = { operation_id:, id: current[:id], expected_revision:,
        action: action == "reminder_reschedule" ? "reschedule" : "complete" }
      attributes.merge!(due_at: plan.fetch("rescheduled_due_at"), entry_zone: ZONE) if action == "reminder_reschedule"
      @operations.change_follow_up(**attributes)
      after = status
      journal!(action, checkpoint, before, after)
      after
    end
  end

  private

  def read_plan
    stat = File.stat(@plan_path)
    raise "Private reminder plan required" unless stat.uid == Process.uid && (stat.mode & 0o077).zero?
    plan = JSON.parse(File.read(@plan_path))
    raise "Reminder timing plan drift" unless plan.values_at("entry_zone", "initial_due_at", "rescheduled_due_at") == [ ZONE, INITIAL_DUE, RESCHEDULED_DUE ]
    plan
  end

  def locked
    File.open(File.join(@directory, "control.lock"), File::RDWR | File::CREAT, 0o600) do |lock|
      lock.flock(File::LOCK_EX)
      yield
    end
  end

  def journal!(action, checkpoint, before, after)
    File.open(File.join(@directory, "reminder-checkpoints.jsonl"), "a", 0o600) do |file|
      file.puts(JSON.generate(at: Time.current.iso8601(6), action:, checkpoint:, before:, after:))
      file.flush
      file.fsync
    end
  end
end
