# Backend-only controls for two explicitly named disposable databases. No HTTP routes.
class BuddyAuthorityFixture
  NAME = "Synthetic Authority American Legion Post"
  DATABASES = %w[legion_buddy_authority_test legion_buddy_authority_verify_test].freeze
  ACTIONS = %w[member_end member_restore pause_on pause_restore coordination_assign coordination_end tier_remove tier_restore attendance_incomplete attendance_first_absence attendance_two_absences attendance_present attendance_excused].freeze

  def self.guard!
    raise "Disposable authority test database required" unless Rails.env.test? && DATABASES.include?(ActiveRecord::Base.connection_db_config.database)
  end

  def self.setup!
    guard!
    raise "Empty database required; never reset a fixture" if Organization.exists? || User.exists? || Person.exists?
    fixture = ApplicationRecord.transaction do
      organization = Organization.create!(name: NAME, unit_type: "american_legion_post", timezone: "America/Chicago")
      Installation.singleton.update!(setup_completed_at: Time.current)
      caller, reviewer, steward = [ [ "Jamie", "Caller", "jamie" ], [ "Riley", "Reviewer", "riley" ], [ "Pat", "Steward", "pat" ] ].map do |first, last, email|
        User.create!(person: Person.create!(first_name: first, last_name: last), email_address: "#{email}@example.test")
      end
      title = organization.position_titles.create!(name: "Synthetic membership reviewer", grants_full_membership_access: true)
      reviewer_position = PositionAssignment.create!(person: reviewer.person, position_title: title, starts_on: Organization.current_local_date - 30)
      PositionAssignment.create!(person: steward.person, position_title: title, starts_on: Organization.current_local_date - 30)
      people = { member: [ "Avery", "Assignment" ], pause: [ "Parker", "Pause" ], coordination: [ "Cameron", "Coordination" ], export: [ "Emerson", "Export" ], attendance: [ "Taylor", "Attendance" ] }.each_with_index.to_h do |(key, names), index|
        person = Person.create!(first_name: names.first, last_name: names.last, member_number: (index + 1).to_s.rjust(12, "0"),
          roster_member_status: key == :member ? "Expired" : "Active", roster_paid_through_year: Organization.current_local_date.year,
          roster_phone_number: "+1-202-555-02#{index.to_s.rjust(2, '0')}", roster_email_address: "#{names.first.downcase}@example.test",
          roster_address: "Synthetic flat label; not an exportable address", roster_imported_at: Time.current)
        [ key, person ]
      end
      drive = organization.membership_drives.create!(title: "Controlled synthetic authority cases", purpose: "buddy_check",
        membership_year: Organization.current_local_date.year, starts_on: Organization.current_local_date - 1, ends_on: Organization.current_local_date + 14, created_by: steward)
      assignment = drive.assignments.create!(person: people.fetch(:member), assigned_to: caller, assigned_by: steward, expires_on: drive.ends_on)
      receipts = { pause: caller, coordination: reviewer }.to_h do |key, user|
        operation_id = SecureRandom.uuid
        BuddyChecks::Operations.new(BuddyChecks::Access.new(user:, organization:)).record(operation_id:, person_id: people.fetch(key).id,
          facts: { channel: "phone", outcome: "reached", occurred_at: 100.days.ago.iso8601(6), entry_zone: "America/Chicago",
            notes: key == :coordination ? "Synthetic private note owned by Riley; never expose to Jamie." : "Synthetic accepted history; preserve through pause." })
        [ key, operation_id ]
      end
      [ caller, reviewer, steward ].each { |user| user.permission_grants.create!(capability: "use_mobile_buddy_checks") }
      [ caller, reviewer ].each { |user| user.permission_grants.create!(capability: "export_buddy_contacts") }
      export_person = people.fetch(:export)
      review = BuddyAddressReview.create!(person: export_person, reviewed_by: steward, source_digest: BuddyAddressReview.source_digest(export_person),
        source_note: "Explicitly reviewed synthetic postal components", components: { "street" => "24 Example Lane", "city" => "Example City", "state" => "WI", "postal_code" => "00000", "country" => "US" })
      body = organization.meeting_bodies.create!(name: "Membership Meeting", slug: "membership")
      meetings = [ 20, 5 ].map do |days|
        organization.meetings.create!(meeting_body: body, title: "Synthetic attendance acceptance", starts_at: days.days.ago.change(hour: 18), location_name: "Example Hall")
      end
      client = Doorkeeper::Application.create!(name: "Synthetic authority Buddy Checks", redirect_uri: "org.wipost165.buddychecks:/oauth/callback", scopes: "buddy_check", confidential: false)
      { organization_id: organization.id, caller_id: caller.id, reviewer_id: reviewer.id, steward_id: steward.id,
        people: people.transform_values(&:id), drive_id: drive.id, member_assignment_id: assignment.id, reviewer_position_id: reviewer_position.id,
        meeting_ids: meetings.map(&:id), address_review_id: review.id, baseline_receipt_ids: receipts,
        issuer: ENV.fetch("MOBILE_BUDDY_CHECK_ISSUER"), client_id: client.uid, callback: client.redirect_uri }
    end
    File.write(ENV.fetch("BUDDY_MOBILE_FIXTURE_FILE"), JSON.pretty_generate(fixture), perm: 0o600)
    fixture
  end

  attr_reader :fixture

  def initialize
    self.class.guard!
    @fixture = JSON.parse(File.read(ENV.fetch("BUDDY_MOBILE_FIXTURE_FILE")))
    @organization = Organization.find(fixture.fetch("organization_id"))
    raise "Wrong synthetic installation" unless Organization.count == 1 && @organization.name == NAME
    raise "Wrong fixture issuer" unless fixture.fetch("issuer") == ENV.fetch("MOBILE_BUDDY_CHECK_ISSUER")
    @caller = User.find(fixture.fetch("caller_id"))
    @reviewer = User.find(fixture.fetch("reviewer_id"))
    @steward = User.find(fixture.fetch("steward_id"))
    @drive = MembershipDrive.find(fixture.fetch("drive_id"))
  end

  def advance!(action, checkpoint:)
    raise "Known action and observed checkpoint required" unless ACTIONS.include?(action) && checkpoint.to_s.strip.length.between?(8, 500)
    directory = File.dirname(ENV.fetch("BUDDY_MOBILE_FIXTURE_FILE"))
    File.open(File.join(directory, "control.lock"), File::RDWR | File::CREAT, 0o600) do |lock|
      lock.flock(File::LOCK_EX)
      before = status
      @organization.with_lock do
        raise "Synthetic steward authority required" unless @steward.reload.full_membership_access?
        case action
        when "member_end"
          assignment = @drive.assignments.where(person: person("member"), assigned_to: @caller, revoked_at: nil).sole
          raise "Assignment is not active" unless assignment.active_on?
          assignment.update!(revoked_at: Time.current)
        when "member_restore"
          raise "End the initial assignment first" if MembershipAssignment.find(fixture.fetch("member_assignment_id")).revoked_at.nil?
          raise "Member already restored" if @drive.assignments.where(person: person("member"), revoked_at: nil).exists?
          assign!("member", @caller)
        when "pause_on", "pause_restore"
          person("pause").with_lock do
            access = BuddyChecks::Access.new(user: @caller, organization: @organization)
            raise "Unexpected pause state" unless access.paused?(person("pause")) == (action == "pause_restore")
            workspace.record_contact!(person_id: person("pause").id, purpose: "buddy_check", channel: "administrative_review",
              outcome: action == "pause_on" ? "do_not_contact" : "contact_permission_restored", occurred_on: Organization.current_local_date,
              notes: "Synthetic authority acceptance: #{action}; #{checkpoint}", submission_key: SecureRandom.uuid)
          end
        when "coordination_assign"
          raise "Coordination assignment already exists" if @drive.assignments.where(person: person("coordination")).exists?
          assign!("coordination", @reviewer)
        when "coordination_end"
          @drive.assignments.where(person: person("coordination"), assigned_to: @reviewer, revoked_at: nil).sole.update!(revoked_at: Time.current)
        when "tier_remove"
          position = PositionAssignment.find(fixture.fetch("reviewer_position_id"))
          raise "Reviewer tier already removed" unless position.ends_on.nil?
          position.update!(ends_on: Organization.current_local_date - 1)
        when "tier_restore"
          raise "Reviewer still has authority" if @reviewer.reload.full_membership_access?
          original = PositionAssignment.find(fixture.fetch("reviewer_position_id"))
          raise "End the original position first" unless original.ends_on
          PositionAssignment.create!(person: @reviewer.person, position_title: original.position_title, starts_on: Organization.current_local_date)
        else
          advance_attendance!(action)
        end
      end
      after = status
      File.open(File.join(directory, "checkpoints.jsonl"), "a", 0o600) do |file|
        file.puts(JSON.generate(at: Time.current.iso8601(6), action:, checkpoint:, before:, after:))
        file.flush
        file.fsync
      end
      after
    end
  end

  def status
    { database: ActiveRecord::Base.connection_db_config.database, issuer: fixture.fetch("issuer"), client_id: fixture.fetch("client_id"),
      accounts: fixture.slice("caller_id", "reviewer_id", "steward_id"), people: fixture.fetch("people"),
      assignments: @drive.assignments.order(:id).map { |row| row.attributes.slice("id", "person_id", "assigned_to_id", "revoked_at", "expires_on") },
      paused: BuddyChecks::Access.new(user: @caller, organization: @organization).paused?(person("pause")), reviewer_authorized: @reviewer.reload.full_membership_access?,
      registers: BuddyAttendanceRegister.where(meeting_id: fixture.fetch("meeting_ids")).order(:id).map { |row| { id: row.id, meeting_id: row.meeting_id, revision: row.revision, complete: row.complete?, attendance: row.entries.fetch(person("attendance").id.to_s) } },
      contacts: MembershipContact.count, receipts: BuddyOperation.count, minutes: MeetingMinutes.count }
  end

  def reconcile(user_id:, person_id:, operation_id:)
    raise "Fixture human/person and original UUID required" unless [ @caller.id, @reviewer.id ].include?(user_id) && fixture.fetch("people").value?(person_id) && BuddyChecks::Operations::UUID.match?(operation_id)
    scope = BuddyOperation.where(organization: @organization, user_id:, operation_id:)
    raise "Operation belongs to a different recipient" if scope.where.not(person_id:).exists?
    contacts = MembershipContact.where(organization: @organization, person_id:)
    { operation_id:, user_id:, person_id:, operation_rows: scope.count,
      accepted_contact_ids: scope.map { |row| row.receipt.dig("contact", "id") }.compact,
      contact_rows: contacts.order(:id).pluck(:id, :logical_contact_id, :revision, :channel, :outcome),
      note: "SQL only: mobile must also GET the same UUID receipt under current authority. Zero rows do not identify whether the client sent a POST." }
  end

  private

  def person(key)
    Person.find(fixture.fetch("people").fetch(key))
  end

  def workspace
    MembershipWorkspace.new(user: @steward, organization: @organization, membership_year: @drive.membership_year)
  end

  def assign!(key, user)
    target = person(key)
    raise "Recipient no longer eligible for drive" unless workspace.eligible_for_drive?(target, @drive)
    @drive.assignments.create!(person: target, assigned_to: user, assigned_by: @steward, expires_on: @drive.ends_on)
  end

  def advance_attendance!(action)
    first, second = fixture.fetch("meeting_ids").map { |id| Meeting.find(id) }
    case action
    when "attendance_incomplete"
      raise "Attendance already started" if BuddyAttendanceRegister.where(meeting: [ first, second ]).exists?
      [ first, second ].each { |meeting| register!(meeting, 0, "absent", complete: false) }
    when "attendance_first_absence" then register!(first, 1, "absent", complete: true)
    when "attendance_two_absences"
      raise "Complete the first absence first" unless BuddyAttendanceRegister.latest.where(meeting: first, revision: 2, complete: true).exists?
      register!(second, 1, "absent", complete: true)
    when "attendance_present" then register!(second, 2, "present", complete: true)
    when "attendance_excused" then register!(second, 3, "excused", complete: true)
    end
  end

  def register!(meeting, expected_revision, attendance, complete:)
    latest = BuddyAttendanceRegister.where(meeting:).order(revision: :desc).first
    ids = latest ? latest.entries.keys : Person.roster_backed.directory_visible.pluck(:id).map(&:to_s)
    entries = ids.to_h { |id| [ id, id == person("attendance").id.to_s ? attendance : (complete ? "present" : "not_recorded") ] }
    BuddyAttendanceRegister.record!(meeting:, user: @steward, expected_revision:, entries:, complete:,
      coverage_note: "Explicit synthetic general-member review for authority acceptance; no official minutes changed.")
  end
end
