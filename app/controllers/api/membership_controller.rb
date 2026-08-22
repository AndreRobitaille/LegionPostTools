module Api
  class MembershipController < BaseController
    before_action :require_full_membership_access
    before_action :prevent_private_data_caching

    def summary
      report = membership_report
      return if performed?

      render json: report.summary
    end

    def renewals
      report = membership_report
      return if performed?

      states = requested_renewal_states
      return if performed?

      people = report.people.select { |person| states.include?(report.renewal_state(person)) }
      page = collection_page(people)
      return if performed?

      render json: page[:metadata].merge(
        membership_year: report.membership_year,
        renewal_states: states,
        roster_source: report.roster_source,
        people: page[:records].map { |person| membership_person_payload(person, report) }
      )
    end

    def roster
      report = membership_report
      return if performed?

      page = collection_page(report.people)
      return if performed?

      render json: page[:metadata].merge(
        membership_year: report.membership_year,
        roster_source: report.roster_source,
        people: page[:records].map { |person| membership_person_payload(person, report) }
      )
    end

    def person
      report = membership_report
      return if performed?

      person = Person.roster_backed.includes(position_assignments: :position_title).find(params[:id])
      render json: {
        membership_year: report.membership_year,
        roster_source: report.roster_source,
        person: membership_person_payload(person, report)
      }
    end

    private

    def membership_report
      MembershipReport.new(membership_year: params[:membership_year])
    rescue ArgumentError => error
      render_error(error.message, status: :unprocessable_entity, details: [ error.message ])
      nil
    end

    def requested_renewal_states
      return MembershipReport::OUTREACH_STATES if params[:state].blank?

      state = params[:state].to_s
      return [ state ] if MembershipReport::RENEWAL_STATES.include?(state)

      message = "state must be one of: #{MembershipReport::RENEWAL_STATES.join(', ')}."
      render_error(message, status: :unprocessable_entity, details: [ message ])
      nil
    end

    def membership_person_payload(person, report)
      {
        id: person.id,
        name: person.roster_display_name,
        roles: person.active_role_labels,
        member_number: person.member_number,
        roster_post: person.roster_post,
        membership_type: person.roster_membership_type,
        member_status: person.roster_member_status,
        paid_through_year: person.roster_paid_through_year,
        paid_up_for_life: person.paid_up_for_life?,
        renewal_state: report.renewal_state(person),
        mailing_address: person.roster_address,
        mail_undeliverable: person.roster_undeliverable?,
        roster_email_address: person.roster_email_address,
        roster_phone_number: person.roster_phone_number,
        branch: person.roster_branch,
        war_era: person.roster_war_era,
        continuous_years: person.roster_continuous_years,
        roster_imported_at: person.roster_imported_at&.iso8601,
        roster_removed_at: person.roster_removed_at&.iso8601
      }
    end
  end
end
