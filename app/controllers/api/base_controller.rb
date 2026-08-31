module Api
  class BaseController < ApplicationController
    UNAUTHORIZED_MESSAGE = "This is a private post operations app. Sign in, then open /api."
    MUTATION_METHODS = %w[POST PATCH PUT DELETE].freeze
    SENSITIVE_PARAMETER_PATTERN = /token|secret|password|code|authenticity/i

    skip_forgery_protection
    before_action :prefer_json
    before_action :authenticate_api_request
    before_action :verify_session_authenticity_token
    around_action :with_agent_idempotency
    after_action :prevent_bearer_caching

    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActionController::InvalidAuthenticityToken, with: :render_invalid_authenticity_token

    helper_method :organization

    def require_authentication
      return if authenticated?

      render_error(UNAUTHORIZED_MESSAGE, status: :unauthorized)
    end

    def require_capability(capability)
      require_authentication
      return if performed?
      return if current_user.can?(capability)

      render_error("You do not have permission to open that.", status: :forbidden)
    end

    def require_full_membership_access
      require_authentication
      return if performed?
      return if current_user.full_membership_access?

      render_error("You do not have permission to open membership information.", status: :forbidden)
    end

    def organization
      Organization.first!
    end

    private

    def prevent_private_data_caching
      response.cache_control.replace(no_store: true)
    end

    def directory_person_payload(person)
      {
        id: person.id,
        name: person.roster_display_name,
        roles: person.active_role_labels,
        email_address: person.directory_email_address,
        phone_number: person.directory_phone_number
      }
    end

    def collection_page(scope, default_limit: 500, max_limit: 500)
      limit = integer_parameter(:limit, default: default_limit)
      offset = integer_parameter(:offset, default: 0)
      raise ArgumentError, "limit must be between 1 and #{max_limit}." unless limit.between?(1, max_limit)
      raise ArgumentError, "offset must be zero or greater." if offset.negative?

      total = scope.size
      records = if scope.is_a?(Array)
        scope.slice(offset, limit) || []
      else
        scope.limit(limit).offset(offset).to_a
      end

      {
        records: records,
        metadata: {
          count: total,
          returned_count: records.size,
          offset: offset,
          limit: limit,
          truncated: offset + records.size < total
        }
      }
    rescue ArgumentError => error
      render_error(error.message, status: :unprocessable_entity, details: [ error.message ])
      nil
    end

    def integer_parameter(name, default:)
      value = params[name]
      return default if value.blank?

      Integer(value.to_s, 10)
    rescue ArgumentError, TypeError
      raise ArgumentError, "#{name} must be an integer."
    end

    def authenticate_api_request
      authorization = request.headers["Authorization"].to_s
      if authorization.present?
        Current.session = nil
        scheme, credential = authorization.split(" ", 2)
        token = AgentAccessToken.authenticate(credential) if scheme&.casecmp?("Bearer")
        return render_error(UNAUTHORIZED_MESSAGE, status: :unauthorized) unless token

        Current.agent_access_token = token
        response.cache_control.replace(no_store: true)
      elsif !authenticated?
        render_error(UNAUTHORIZED_MESSAGE, status: :unauthorized)
      end
    end

    def prevent_bearer_caching
      response.headers["Cache-Control"] = "no-store" if Current.agent_access_token
    end

    def verify_session_authenticity_token
      return unless mutation_request? && Current.agent_access_token.blank?
      return unless protect_against_forgery?
      return if verified_request?

      raise ActionController::InvalidAuthenticityToken
    end

    def with_agent_idempotency
      return yield unless mutation_request? && Current.agent_access_token.present?

      key = request.headers["Idempotency-Key"].to_s
      if key.blank? || key.length > 255
        return render_error("Bearer-authenticated writes require an Idempotency-Key of 255 characters or fewer.", status: :unprocessable_entity)
      end

      token = Current.agent_access_token
      fingerprint = request_fingerprint
      token.with_lock do
        token.reload
        unless token.active?
          return render_error(UNAUTHORIZED_MESSAGE, status: :unauthorized)
        end

        execution = token.agent_api_executions.find_by(idempotency_key: key)
        if execution
          unless matching_execution?(execution, fingerprint)
            return render_error("That Idempotency-Key was already used for a different request.", status: :conflict)
          end
          return replay_execution(execution) if execution.completed?

          return render_error("That request is still processing. Retry it with the same Idempotency-Key.", status: :conflict)
        end

        execution = token.agent_api_executions.create!(
          user: current_user,
          idempotency_key: key,
          request_method: request.request_method,
          request_path: request.path,
          request_fingerprint: fingerprint,
          state: "processing"
        )

        yield
        execution.update!(
          state: "completed",
          response_status: response.status,
          response_body: response.body
        )
      end
    end

    def mutation_request?
      MUTATION_METHODS.include?(request.request_method)
    end

    def request_fingerprint
      payload = fingerprint_value(request.request_parameters.deep_stringify_keys)
      canonical = JSON.generate(deep_sort(payload))
      Digest::SHA256.hexdigest([ request.request_method, request.path, canonical ].join("\n"))
    end

    def fingerprint_value(value, sensitive: false)
      return sensitive_fingerprint(value) if sensitive

      case value
      when Hash
        value.each_with_object({}) do |(key, child), fingerprinted|
          fingerprinted[key] = fingerprint_value(child, sensitive: key.match?(SENSITIVE_PARAMETER_PATTERN))
        end
      when Array
        value.map { |child| fingerprint_value(child) }
      else
        value
      end
    end

    def sensitive_fingerprint(value)
      canonical = JSON.generate(deep_sort(value))
      "hmac:#{OpenSSL::HMAC.hexdigest('SHA256', Rails.application.secret_key_base, canonical)}"
    end

    def deep_sort(value)
      case value
      when Hash
        value.keys.sort.to_h { |key| [ key, deep_sort(value[key]) ] }
      when Array
        value.map { |child| deep_sort(child) }
      else
        value
      end
    end

    def matching_execution?(execution, fingerprint)
      execution.request_method == request.request_method &&
        execution.request_path == request.path &&
        ActiveSupport::SecurityUtils.secure_compare(execution.request_fingerprint, fingerprint)
    end

    def replay_execution(execution)
      render body: execution.response_body,
        status: execution.response_status,
        content_type: "application/json; charset=utf-8"
    end

    def prefer_json
      request.format = :json
    end

    def render_error(message, status:, details: [])
      payload = { error: message, details: Array(details) }
      if json_request?
        render json: payload, status: status
      else
        render plain: message, status: status, content_type: "text/plain; charset=utf-8"
      end
    end

    def json_request?
      request.format.json? || request.headers["Accept"].to_s.include?("application/json")
    end

    def render_not_found
      render_error("Not found.", status: :not_found)
    end

    def render_invalid_authenticity_token
      render json: {
        error: "The security token is missing or expired. Open /api again, then retry the request.",
        details: []
      }, status: :unprocessable_entity
    end

    def render_validation_error(record, fallback:)
      render_error(
        record.errors.full_messages.to_sentence.presence || fallback,
        status: :unprocessable_entity,
        details: record.errors.full_messages
      )
    end

    def meeting_body_payload(meeting_body)
      return nil if meeting_body.nil?

      { id: meeting_body.id, name: meeting_body.name, slug: meeting_body.slug }
    end

    def meeting_type_payload(meeting_type)
      return nil if meeting_type.nil?

      { id: meeting_type.id, name: meeting_type.name, slug: meeting_type.slug, active: meeting_type.active }
    end

    def agenda_summary_payload(agenda)
      {
        id: agenda.id,
        meeting_id: agenda.meeting_id,
        title: agenda.title,
        status: agenda.status,
        starts_at: agenda.starts_at.iso8601,
        location_name: agenda.location_name,
        location_address: agenda.location_address,
        meeting_body: meeting_body_payload(agenda.meeting_body),
        meeting_type: meeting_type_payload(agenda.meeting_type)
      }
    end

    def meeting_payload(meeting)
      {
        id: meeting.id,
        title: meeting.title,
        starts_at: meeting.starts_at.iso8601,
        location_name: meeting.location_name,
        location_address: meeting.location_address,
        lock_version: meeting.lock_version,
        meeting_body: meeting_body_payload(meeting.meeting_body),
        meeting_type: meeting_type_payload(meeting.meeting_type),
        agenda: meeting.dated_agenda ? {
          id: meeting.dated_agenda.id,
          status: meeting.dated_agenda.status
        } : nil,
        transcript: meeting.transcript ? transcript_summary_payload(meeting.transcript) : nil,
        minutes: meeting.minutes ? minutes_summary_payload(meeting.minutes) : nil
      }
    end

    def transcript_summary_payload(transcript)
      {
        id: transcript.id,
        meeting_id: transcript.meeting_id,
        source_kind: transcript.source_kind,
        original_filename: transcript.original_filename,
        byte_size: transcript.byte_size,
        media_type: transcript.media_type,
        retention_policy: transcript.retention_policy,
        source_available: transcript.source_available?,
        created_by: directory_person_payload(transcript.created_by.person),
        created_at: transcript.created_at.iso8601,
        purged_at: transcript.purged_at&.iso8601
      }
    end

    def minutes_summary_payload(minutes)
      {
        id: minutes.id,
        meeting_id: minutes.meeting_id,
        status: minutes.status,
        title: minutes.title,
        starts_at: minutes.starts_at.iso8601,
        location_name: minutes.location_name,
        lock_version: minutes.lock_version,
        updated_at: minutes.updated_at.iso8601,
        lifecycle: minutes_lifecycle_payload(minutes)
      }
    end

    def minutes_detail_payload(minutes)
      minutes_summary_payload(minutes).merge(
        location_address: minutes.location_address,
        meeting_body: meeting_body_payload(minutes.meeting_body),
        meeting_type: meeting_type_payload(minutes.meeting_type),
        draft_pdf_path: "/api/meetings/#{minutes.meeting_id}/minutes/print",
        attendance: minutes.attendance_entries.map { |entry| minutes_attendance_payload(entry) },
        sections: minutes.sections.map { |section| minutes_section_payload(section) },
        draft_runs: minutes.draft_runs.map { |run| minutes_draft_run_payload(run) }
      )
    end

    def minutes_lifecycle_payload(minutes)
      revision = minutes.current_revision
      {
        status: minutes.status,
        approval_ready: minutes.draft? ? minutes.approval_ready? : nil,
        revision: revision ? revision_payload(revision) : nil,
        member_visible: minutes.attested? || minutes.accepted?,
        member_minutes_path: ("/meetings/#{minutes.meeting_id}/minutes" if minutes.attested? || minutes.accepted?),
        next_action: minutes_next_action(minutes)
      }
    end

    def minutes_next_action(minutes)
      {
        "draft" => "approve",
        "approved" => "attest",
        "attested" => "await_membership_acceptance"
      }[minutes.status]
    end

    def revision_payload(revision)
      {
        id: revision.id,
        number: revision.number,
        sha256: revision.sha256,
        approved_by: revision.approver_name,
        approver_office: revision.approver_office,
        approved_at: revision.approved_at.iso8601,
        attestation: revision.attestation ? attestation_payload(revision.attestation) : nil
      }
    end

    def attestation_payload(attestation)
      {
        id: attestation.id,
        attested_by: attestation.attester_name,
        attester_office: attestation.attester_office,
        attested_at: attestation.attested_at.iso8601,
        recorded_by: directory_person_payload(attestation.recorded_by.person),
        confirmation_method: attestation.official_action_confirmation.confirmation_method
      }
    end

    def minutes_section_payload(section)
      {
        id: section.id,
        title: section.title,
        position: section.position,
        source_dated_agenda_section_id: section.source_dated_agenda_section_id,
        lock_version: section.lock_version,
        items: section.items.map { |item| minutes_item_payload(item) }
      }
    end

    def minutes_item_payload(item)
      {
        id: item.id,
        minutes_section_id: item.minutes_section_id,
        source_dated_agenda_item_id: item.source_dated_agenda_item_id,
        endeavor_id: item.endeavor_id,
        record_key: item.record_key,
        title: item.title,
        behavior_type: item.behavior_type,
        position: item.position,
        agenda_wording: item.agenda_body.to_plain_text.presence,
        body: item.body.to_plain_text.presence,
        lock_version: item.lock_version,
        outcomes: item.outcomes.map { |outcome| minutes_outcome_payload(outcome) }
      }
    end

    def minutes_outcome_payload(outcome)
      {
        id: outcome.id,
        minutes_item_id: outcome.minutes_item_id,
        kind: outcome.kind,
        text: outcome.text,
        mover_person_id: outcome.mover_person_id,
        mover_name: outcome.mover_name,
        seconder_person_id: outcome.seconder_person_id,
        seconder_name: outcome.seconder_name,
        disposition: outcome.disposition,
        disposition_label: minutes_disposition_label(outcome.disposition),
        vote_summary: outcome.vote_summary,
        position: outcome.position,
        lock_version: outcome.lock_version
      }
    end

    def minutes_disposition_label(disposition)
      {
        "adopted" => "Passed",
        "lost" => "Did not pass",
        "withdrawn" => "Withdrawn",
        "postponed" => "Postponed",
        "referred" => "Referred",
        "no_vote" => "No vote taken",
        "not_recorded" => "Needs review"
      }.fetch(disposition)
    end

    def minutes_attendance_payload(entry)
      {
        id: entry.id,
        dated_agenda_roll_call_entry_id: entry.dated_agenda_roll_call_entry_id,
        position_title_id: entry.position_title_id,
        person_id: entry.person_id,
        office_name: entry.office_name,
        person_name: entry.person_name,
        status: entry.status,
        position: entry.position,
        lock_version: entry.lock_version
      }
    end

    def minutes_draft_run_payload(run, include_suggestions: false)
      payload = {
        id: run.id,
        meeting_minutes_id: run.meeting_minutes_id,
        meeting_id: run.meeting_minutes.meeting_id,
        meeting_transcript_id: run.meeting_transcript_id,
        status: run.status,
        provider: run.provider,
        model: run.model,
        reasoning_effort: run.reasoning_effort,
        text_verbosity: run.text_verbosity,
        prompt_version: run.prompt_version,
        schema_version: run.schema_version,
        source_line_count: run.source_line_count,
        requested_by: directory_person_payload(run.requested_by.person),
        retry_of_id: run.retry_of_id,
        discarded: run.discarded?,
        discarded_at: run.discarded_at&.iso8601,
        error_category: run.error_category,
        input_tokens: run.input_tokens,
        output_tokens: run.output_tokens,
        reasoning_tokens: run.reasoning_tokens,
        total_tokens: run.total_tokens,
        started_at: run.started_at&.iso8601,
        completed_at: run.completed_at&.iso8601,
        created_at: run.created_at.iso8601,
        updated_at: run.updated_at.iso8601,
        review_counts: run.suggestions.reorder(nil).group(:review_state).count
      }
      payload[:suggestions] = run.suggestions.map { |suggestion| minutes_draft_suggestion_payload(suggestion) } if include_suggestions
      payload
    end

    def minutes_draft_suggestion_payload(suggestion)
      {
        id: suggestion.id,
        kind: suggestion.kind,
        confidence: suggestion.confidence,
        review_state: suggestion.review_state,
        payload: suggestion.payload,
        missing_facts: suggestion.missing_facts,
        source_start_line: suggestion.source_start_line,
        source_end_line: suggestion.source_end_line,
        minutes_item_id: suggestion.minutes_item_id,
        minutes_attendance_entry_id: suggestion.minutes_attendance_entry_id,
        minutes_section_id: suggestion.minutes_section_id,
        source_dated_agenda_item_id: suggestion.source_dated_agenda_item_id,
        reviewed_by: suggestion.reviewed_by ? directory_person_payload(suggestion.reviewed_by.person) : nil,
        reviewed_at: suggestion.reviewed_at&.iso8601,
        applied_record_type: suggestion.applied_record_type,
        applied_record_id: suggestion.applied_record_id
      }
    end

    def user_account_payload(person)
      user = person.user
      {
        person_id: person.id,
        person_name: person.roster_display_name,
        roster_managed: person.roster_backed?,
        roster_status: person.roster_member_status,
        roster_removed_at: person.roster_removed_at&.iso8601,
        account: user ? {
          id: user.id,
          email_address: user.email_address,
          enabled: user.disabled_at.blank?,
          disabled_at: user.disabled_at&.iso8601,
          disabled_reason: user.disabled_reason,
          disabled_reason_detail: user.disabled_reason_detail,
          login_access_override: user.login_access_override,
          capabilities: user.permission_grants.order(:capability).pluck(:capability)
        } : nil
      }
    end

    def agenda_detail_payload(agenda)
      agenda_summary_payload(agenda).merge(
        sections: agenda.dated_agenda_sections.ordered.includes(
          agenda_items: [ :rich_text_body, :rich_text_commander_notes, { roll_call_entries: %i[position_title person] } ]
        ).map { |section| dated_agenda_section_payload(section) }
      )
    end

    def dated_agenda_section_payload(section)
      {
        id: section.id,
        title: section.title,
        position: section.position,
        items: section.agenda_items.order(:position, :title).map { |item| dated_agenda_item_payload(item) }
      }
    end

    def dated_agenda_item_payload(item)
      {
        id: item.id,
        dated_agenda_section_id: item.dated_agenda_section_id,
        title: item.title,
        summary: item.summary,
        position: item.position,
        behavior_type: item.behavior_type,
        endeavor_id: item.endeavor_id,
        wording: item.body.to_plain_text.presence,
        show_wording_on_agenda: item.show_wording_on_agenda,
        show_wording_in_minutes: item.show_wording_in_minutes,
        commander_notes: item.commander_notes.to_plain_text.presence,
        lock_version: item.lock_version,
        roll_call: item.roll_call? ? item.roll_call_entries.map { |entry| dated_roll_call_entry_payload(entry) } : nil
      }
    end

    def dated_roll_call_entry_payload(entry)
      {
        id: entry.id,
        position_title_id: entry.position_title_id,
        person_id: entry.person_id,
        office: entry.office_name,
        officer: entry.person_name,
        position: entry.position,
        vacant: entry.vacant?
      }
    end

    def agenda_catalog_entry_payload(entry)
      {
        id: entry.id,
        title: entry.title,
        summary: entry.summary,
        category: entry.category,
        category_label: AgendaItemCatalogEntry::CATEGORIES.fetch(entry.category, entry.category.humanize),
        position: entry.position,
        behavior_type: entry.behavior_type,
        active: entry.active,
        wording: entry.body.to_plain_text.presence,
        show_wording_on_agenda: entry.show_wording_on_agenda,
        show_wording_in_minutes: entry.show_wording_in_minutes,
        commander_notes: entry.commander_notes.to_plain_text.presence,
        seeded: entry.seeded?
      }
    end
  end
end
