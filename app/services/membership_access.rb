class MembershipAccess
  attr_reader :user, :organization

  def initialize(user:, organization:, membership_year: nil)
    @user = user
    @organization = organization
    @membership_year = membership_year
  end

  def manager?
    user.disabled_at.nil? && user.full_membership_access?
  end

  def assignments
    scope = MembershipAssignment.joins(:membership_drive).where(membership_drives: { organization_id: organization.id })
    scope = scope.where(membership_drives: { membership_year: @membership_year }) if @membership_year
    return scope if manager?
    return scope.none if user.disabled_at.present?

    scope.where(assigned_to: user).active_on(Organization.current_local_date)
  end

  def drives
    scope = organization.membership_drives
    manager? ? scope : scope.where(id: assignments.select(:membership_drive_id))
  end

  def people
    scope = Person.roster_backed
    return scope if manager?

    scope.where(id: assignments.select(:person_id)).where(roster_removed_at: nil)
      .where("LOWER(TRIM(COALESCE(roster_member_status, ''))) != ?", "deceased")
  end

  def contacts
    scope = organization.membership_contacts
    return scope if manager?

    permitted = scope.where(person_id: people.select(:id))
    own_assignments = MembershipAssignment.joins(:membership_drive)
      .where(assigned_to: user, membership_drives: { organization_id: organization.id }).select(:id)
    permitted.where(recorded_by: user).or(permitted.where(membership_assignment_id: own_assignments))
  end

  def permitted?
    manager? || people.exists?
  end

  def drive_assignments(drive, caller_id: nil)
    scope = assignments.where(membership_drive: drive)
    scope = scope.where(assigned_to_id: caller_id) if caller_id.present?
    scope.includes(:person, assigned_to: :person).order("people.last_name", "people.first_name")
  end
end
