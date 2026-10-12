module BuddyChecks
  class Access
    attr_reader :user, :organization

    def initialize(user:, organization:)
      @user, @organization = user, organization
    end

    def enabled!
      raise Denied, "account_unavailable" unless user.reload.disabled_at.nil?
    end

    def assignments
      MembershipAssignment.joins(:membership_drive).active_on(Organization.current_local_date)
        .where(assigned_to: user, membership_drives: { organization_id: organization.id, purpose: "buddy_check" })
    end

    def people
      enabled!
      Person.directory_visible.or(Person.where(id: assignments.select(:person_id)))
        .where(roster_removed_at: nil).where("LOWER(TRIM(COALESCE(roster_member_status, ''))) != 'deceased'")
    end

    def person!(id)
      people.find(id)
    end

    def permission!(person)
      person!(person.id)
      raise Denied, "contact_paused" if paused?(person)
    end

    def paused?(person)
      organization.membership_contacts.effective.where(person:, purpose: "buddy_check",
        outcome: %w[do_not_contact contact_permission_restored]).recent.first&.outcome == "do_not_contact"
    end

    def owned_contacts
      own_assignment_ids = MembershipAssignment.where(assigned_to: user).select(:id)
      scope = organization.membership_contacts.where(purpose: "buddy_check",
        outcome: %w[reached no_answer message_left callback_requested wrong_number not_attempted]).where.not(channel: "administrative_review")
      scope.where(recorded_by: user).or(scope.where(membership_assignment_id: own_assignment_ids))
        .where(person_id: people.select(:id))
    end

    def follow_ups
      BuddyFollowUp.where(organization:, user:, person_id: people.select(:id))
    end

    def snoozes
      BuddySnooze.where(organization:, user:, person_id: people.select(:id))
    end

    def export_enabled?
      Configuration.export_enabled? && user.can?("export_buddy_contacts")
    end
  end
end
