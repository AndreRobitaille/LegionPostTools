module Api
  module Mobile
    module V1
      class BuddyChecksController < BaseController
        def session
          body = { installation: { id: @access.organization.id, issuer: BuddyChecks::Configuration.issuer,
            name: @access.organization.name, timezone: @access.organization.calendar_time_zone.tzinfo.identifier },
            user: { id: @access.user.id, name: @access.user.person.full_name }, session_id: @token.id,
            expires_at: (@token.created_at + @token.expires_in).iso8601(6),
            capabilities: { buddy_checks: true, contacts_export: @access.export_enabled?, refresh: @remembered_session.present? } }
          render json: body.merge(@remembered_session ? @remembered_session.identity : {})
        end

        def people
          scope = BuddyChecks::PeopleSearch.new(@access.people).call(params[:q])
          render json: page(scope) { |person| identity(person) }
        end

        def person
          person = @access.person!(params[:id])
          eligibility = suggestions.eligibility(person)
          render json: identity(person).merge(eligibility:, phone: eligibility[:eligible] ? person.directory_phone_number : nil,
            email: eligibility[:eligible] ? person.directory_email_address : nil, coverage: suggestions.coverage,
            assignment_ids: @access.assignments.where(person:).pluck(:id), export_available: @access.export_enabled?)
        end

        def suggestion
          render json: suggestions.suggest(exclude_ids: Array(params[:exclude_ids]))
        end

        def create
          render json: @operations.record(**payload.slice(:operation_id, :person_id, :facts, :follow_up, :assignment_id)), status: :created
        end

        def correct
          render json: @operations.correct(id: params[:id], **payload.slice(:operation_id, :expected_revision, :facts)), status: :created
        end

        def receipt
          render json: @operations.receipt(params[:operation_id])
        end

        def mine
          render json: page(@access.owned_contacts.effective) { |contact| @operations.contact_payload(contact) }
        end

        def revisions
          contact = @access.owned_contacts.find(params[:id])
          root_id = contact.logical_contact_id || contact.id
          @access.permission!(contact.person)
          scope = @access.owned_contacts.where("id = :id OR logical_contact_id = :id", id: root_id)
          render json: page(scope) { |revision| @operations.contact_payload(revision) }
        end

        def follow_ups
          render json: page(@access.follow_ups) { |follow_up| @operations.follow_up_payload(follow_up) }
        end

        def schedule
          render json: @operations.schedule(**payload.slice(:operation_id, :person_id, :due_at, :entry_zone)), status: :created
        end

        def change_follow_up
          render json: @operations.change_follow_up(id: params[:id], **payload.slice(:operation_id, :expected_revision, :action, :due_at, :entry_zone)), status: :created
        end

        def snoozes
          render json: page(@access.snoozes) { |snooze| @operations.snooze_payload(snooze) }
        end

        def snooze
          render json: @operations.snooze(**payload.slice(:operation_id, :person_id, :until_at)), status: :created
        end

        def undo_snooze
          render json: @operations.undo_snooze(id: params[:id], **payload.slice(:operation_id, :expected_revision)), status: :created
        end

        def contact_export
          render json: BuddyChecks::ContactExport.new(@access).call(@access.person!(params[:id]))
        end

        private

        def identity(person)
          { id: person.id, first_name: person.first_name, last_name: person.last_name }
        end

        def suggestions
          @suggestions ||= BuddyChecks::Suggestions.new(@access)
        end
      end
    end
  end
end
