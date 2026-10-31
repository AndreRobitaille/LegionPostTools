module EndeavorHistory
  module Requests
    module_function

    def record_attestation(minutes)
      return unless Config.enabled?

      minutes.organization.endeavors.where(history_withdrawn: false).find_each do |endeavor|
        endeavor.history_events.create!(action: "attestation_requested", metadata: {
          "revision_id" => minutes.current_revision_id, "manifest" => Sources.new(endeavor).request_inputs
        })
      end
    end

    def latest(endeavor)
      endeavor.history_events.where(action: "attestation_requested").order(id: :desc).first
    end

    def context(manifest) = Sources.dependencies(manifest).except("revisions")

    def revision_ids(endeavor, manifest)
      # Journal IDs are allocated before commit and do not establish commit order.
      # The run's frozen source snapshot bounds work, including overlapping requests.
      endeavor.history_events.where(action: "attestation_requested").filter_map do |request|
        request.metadata["revision_id"] if valid?(endeavor, request, manifest)
      end.uniq & manifest.fetch("revisions").pluck("id")
    end

    def valid?(endeavor, request, manifest)
      request && request.persisted? && request.endeavor_id == endeavor.id &&
        request.action == "attestation_requested" &&
        context(request.metadata.fetch("manifest")) == context(manifest)
    end

    def pending(endeavor)
      manifest = Sources.new(endeavor).request_inputs
      endeavor.history_events.where(action: "attestation_requested").order(id: :desc).detect do |request|
        valid?(endeavor, request, manifest) && !resolved?(endeavor, request)
      end
    end

    def resolved?(endeavor, request)
      endeavor.history_events.where(action: %w[requested attestation_resolved])
        .where("metadata ->> 'attestation_request_id' = ?", request.id.to_s).exists?
    end

    def enqueue(endeavor, request = pending(endeavor))
      return unless Config.enabled? && !endeavor.history_withdrawn?
      return unless valid?(endeavor, request, Sources.new(endeavor).request_inputs)
      return if resolved?(endeavor, request)

      begin
        EndeavorHistoryRefreshJob.perform_later(endeavor.id, request.id)
      rescue StandardError => error
        Rails.logger.warn("Endeavor history request #{request.id} enqueue failed (#{error.class.name})")
        nil
      end
    end

    def metadata(run)
      run.endeavor.history_events.where(action: "requested", endeavor_history_run: run).last&.metadata || {}
    end

    def authorized_run?(run)
      event = run.endeavor.history_events.where(action: "requested", endeavor_history_run: run).last
      return false unless event
      if run.requested_by_id
        return event.actor_id == run.requested_by_id && event.agent_access_token_id == run.agent_access_token_id
      end
      return true if event.metadata["trigger"] == "backfill"

      request = run.endeavor.history_events.find_by(id: event.metadata["attestation_request_id"], action: "attestation_requested")
      request && context(request.metadata.fetch("manifest")) == context(run.manifest)
    end

    def retry_root(run)
      request = metadata(run)
      request["retry_root_id"] || (request["refresh_id"] if request["refresh"]) || run.id
    end

    def attempts(run)
      attempt_events(run).count
    end

    def latest_attempt(run)
      attempt_events(run).order(id: :desc).first&.endeavor_history_run || run
    end

    def attempt_events(run)
      root = retry_root(run)
      run.endeavor.history_events.where(action: "requested")
        .where("metadata ->> 'retry_root_id' = :root OR metadata ->> 'refresh_id' = :root OR endeavor_history_run_id = :id", root: root.to_s, id: root)
    end

    def retryable?(run)
      return false unless run.status == "failed" && authorized_run?(run) && run.finished_at
      %w[queue_error worker_stalled timeout rate_limit provider_error].include?(run.error_category) &&
        run.finished_at < 15.minutes.ago && attempts(run) < 3
    end

    def defer_recovery(run)
      events = run.endeavor.history_events.where(action: "recovery_deferred", endeavor_history_run: run)
      events.create!(metadata: { "reason" => "dependencies_changed" }) unless events.exists?
    end
  end
end
