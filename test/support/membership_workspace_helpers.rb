module MembershipWorkspaceHelpers
  def setup_membership_workspace
    @organization = Organization.create!(name: "Example American Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @officer = membership_user("Officer")
    @volunteer = membership_user("Volunteer")
    @other = membership_user("Other")
    @title = @organization.position_titles.create!(name: "Membership Officer", display_order: 1, grants_full_membership_access: true)
    @office = PositionAssignment.create!(person: @officer.person, position_title: @title, starts_on: Organization.current_local_date - 10)
    @year = MembershipWorkspace.default_year
    @member = membership_person("Alex", 1)
    @unassigned = membership_person("Taylor", 2)
    @drive = @organization.membership_drives.create!(title: "Fall renewal calls", purpose: "renewal", membership_year: @year,
      starts_on: Organization.current_local_date - 2, ends_on: Organization.current_local_date + 30, created_by: @officer,
      script: "Introduce yourself. Ask how the Post can help and agree on the next step.")
    @assignment = @drive.assignments.create!(person: @member, assigned_to: @volunteer, assigned_by: @officer, expires_on: @drive.ends_on)
  end

  def membership_user(name)
    User.create!(person: Person.create!(first_name: name, last_name: "Helper"), email_address: "#{name.downcase}@example.com")
  end

  def membership_person(name, number)
    Person.create!(first_name: name, last_name: "Member", member_number: number.to_s.rjust(12, "0"),
      roster_member_status: "Active", roster_membership_type: "Member", roster_paid_through_year: @year - 1,
      roster_imported_at: Time.current, roster_phone_number: "555-010#{number}", roster_email_address: "#{name.downcase}@example.com")
  end

  def workspace(user = @officer, year = @year)
    MembershipWorkspace.new(user:, organization: @organization, membership_year: year)
  end

  def contact_attributes(**attributes)
    { person_id: @member.id, membership_assignment_id: @assignment.id, channel: "phone", outcome: "reached",
      occurred_on: Organization.current_local_date, submission_key: SecureRandom.uuid }.merge(attributes)
  end

  def dues_attributes(**attributes)
    { person_id: @member.id, kind: "post_receipt", amount: "45.00", received_on: Organization.current_local_date,
      submission_key: SecureRandom.uuid }.merge(attributes)
  end
end
