module EndeavorHistory
  class Processing
    def self.request(endeavor, requester: nil, force: false, meeting_id: nil)
      raise Error, "disabled" unless Config.enabled?
      raise Error, "forbidden" if requester && !requester.can?("manage_agendas")
      run = endeavor.with_lock do
        raise Error, "withdrawn" if endeavor.history_withdrawn?
        existing = endeavor.history_runs.active.first
        next existing if existing
        manifest = Sources.new(endeavor).manifest
        raise Error, "no_sources" if manifest["revisions"].empty?
        fingerprint = Sources.digest(manifest)
        latest = endeavor.history_runs.where(fingerprint: fingerprint).order(id: :desc).first
        next latest if latest && !force
        run = endeavor.history_runs.create!(manifest: manifest, fingerprint: fingerprint, requested_by: requester,
          agent_access_token_id: Current.agent_access_token&.id)
        endeavor.history_events.create!(action: "requested", actor: requester, endeavor_history_run: run,
          agent_access_token_id: Current.agent_access_token&.id, metadata: { "meeting_id" => meeting_id, "force" => force })
        run
      end
      if run.status == "pending"
        job = EndeavorHistoryJob.perform_later(run.id)
        run.update!(status: "failed", error_category: "queue_error", finished_at: Time.current) unless job&.successfully_enqueued?
      end
      run
    end

    def initialize(run, provider: Provider.new)
      @run = run
      @endeavor = run.endeavor
      @provider = provider
    end

    def call
      claimed = @run.with_lock do
        next false unless @run.status == "pending"
        @run.update!(status: "running", started_at: Time.current, heartbeat_at: Time.current)
        true
      end
      return unless claimed
      ensure_current!
      documents = Sources.new(@endeavor).documents
      @guidance = @endeavor.history_guidances.find_by(id: @run.manifest["guidance_id"])&.body.to_s
      meetings = documents.map { |document| discover(document) }
      context = { "endeavor" => @run.manifest["endeavor"], "guidance" => @guidance, "meetings" => meetings }
      summary = if meetings.any? { |meeting| meeting["facts"].any? }
        generate_verified("summary", context, Schemas.summary) { |data| Validate.summary!(data, meetings) }
      else
        { "overview" => [], "meetings" => [] }
      end
      publish!(summary, meetings)
    rescue Error => error
      finish_failure(error.category)
    rescue StandardError => error
      finish_failure("worker_error")
      Rails.logger.error("Endeavor history run #{@run.id} failed (#{error.class.name})")
      raise
    end

    private

    def discover(document)
      items = document.fetch("items")
      results = []
      # Keep source items whole. Oversized single items stop explicitly rather than losing text.
      batches = []
      items.each do |item|
        candidate = (batches.last || []) + [ item ]
        if batches.empty? || JSON.generate(candidate).bytesize > Config.max_input_bytes / 3
          batches << [ item ]
        else
          batches[-1] = candidate
        end
      end
      batches.each do |batch|
        source = document.merge("items" => batch, "target_endeavor_id" => @endeavor.id)
        input = { "endeavor" => @run.manifest["endeavor"], "catalog" => @run.manifest["catalog"], "guidance" => @guidance, "source" => source }
        output = generate_verified("discovery", input, Schemas.discovery) { |data| Validate.discovery!(data, source) }
        results.concat(output.fetch("items"))
      end
      facts = results.flat_map do |entry|
        entry.fetch("facts").each_with_index.map do |fact, index|
          fact.merge("id" => "r#{document['revision_id']}:#{entry['key']}:fact:#{index}")
        end
      end
      source_ids = facts.flat_map { |fact| fact["source_ids"] }.uniq
      # Preserve the whole associated item as context, but only selected units are featured.
      selected = document["items"].select { |item| item["units"].any? { |unit| source_ids.include?(unit["id"]) } }
      document.merge("items" => selected, "facts" => facts, "coverage" => results)
    end

    def generate_verified(stage, input, schema)
      repair = nil
      2.times do |attempt|
        request_input = repair ? input.merge("repair_findings" => repair) : input
        candidate = invoke(stage, request_input, schema)
        begin
          yield candidate
          verification_input = input.merge("candidate" => candidate)
          report = invoke("verify_#{stage}", verification_input, Schemas.verification)
          allowed = source_ids(input)
          Validate.verification!(report, allowed)
          return candidate
        rescue Error => error
          raise if attempt == 1
          repair = { "category" => error.category, "candidate" => candidate, "verification" => report }
        end
      end
    end

    def source_ids(input)
      documents = input["source"] ? [ input["source"] ] : input.fetch("meetings")
      documents.flat_map { |document| document.fetch("items").flat_map { |item| item.fetch("units").map { |unit| unit["id"] } } }
    end

    def invoke(stage, input, schema)
      ensure_current!
      serialized = JSON.generate(input)
      raise Error, "input_limit" if serialized.bytesize > Config.max_input_bytes
      index = nil
      @endeavor.organization.with_lock do
        @run.reload
        raise Error, "call_budget" if @run.steps.length >= Config.max_calls
        # Reserve conservatively before making a paid call, including responses lost to timeouts.
        reserved = serialized.bytesize + Prompt.instructions(stage).bytesize + JSON.generate(schema).bytesize + Config.max_output_tokens
        used = EndeavorHistoryRun.joins(:endeavor).where(endeavors: { organization_id: @endeavor.organization_id })
          .where(updated_at: Time.current.beginning_of_day..).sum do |run|
            run.steps.sum { |step| step["at"] && Time.iso8601(step["at"]) >= Time.current.beginning_of_day ? step.fetch("total_tokens", 0).to_i : 0 }
          end
        raise Error, "daily_budget" if used + reserved > Config.daily_token_budget
        index = @run.steps.length
        @run.update!(steps: @run.steps + [ { "stage" => stage, "input_sha256" => Sources.digest(input),
          "total_tokens" => reserved, "reserved" => true, "at" => Time.current.iso8601, "reasoning" => Config.reasoning(stage) } ], heartbeat_at: Time.current)
      end
      result = @provider.call(stage: stage, input: input, schema: schema)
      @run.with_lock do
        steps = @run.steps.deep_dup
        usage = result.fetch("total_tokens", 0).to_i
        recorded = result.merge("reserved" => usage <= 0)
        recorded["total_tokens"] = steps[index]["total_tokens"] if usage <= 0
        steps[index].merge!(recorded)
        @run.update!(steps: steps, heartbeat_at: Time.current)
      end
      result.fetch("data")
    end

    def ensure_current!
      raise Error, "disabled" unless Config.enabled?
      @run.reload
      raise Error, "superseded" unless @run.status == "running"
      @endeavor.reload
      raise Error, "withdrawn" if @endeavor.history_withdrawn?
      if @run.requested_by && (@run.requested_by.reload.disabled_at.present? || !@run.requested_by.can?("manage_agendas"))
        raise Error, "forbidden"
      end
      if @run.agent_access_token_id
        token = AgentAccessToken.find_by(id: @run.agent_access_token_id)
        raise Error, "forbidden" unless token&.active?
      end
      raise Error, "source_changed" unless Sources.digest(Sources.new(@endeavor).manifest) == @run.fingerprint
    end

    def publish!(summary, meetings)
      @endeavor.with_lock do
        # Serialize against official transitions as well as guidance/withdrawal changes.
        minutes_ids = MinutesRevision.where(id: @run.manifest["revisions"].map { |source| source["id"] }).pluck(:meeting_minutes_id)
        MeetingMinutes.where(id: minutes_ids).order(:id).lock.load
        ensure_current!
        payload = summary.merge("evidence" => meetings)
        edition = @endeavor.history_editions.create!(endeavor_history_run: @run, payload: payload,
          manifest: @run.manifest, sha256: Sources.digest(payload))
        meetings.each do |meeting|
          ids = meeting["facts"].flat_map { |fact| fact["source_ids"] }.uniq
          meeting["items"].each do |item|
            selected_ids = item["units"].map { |unit| unit["id"] } & ids
            next if selected_ids.empty?
            edition.source_links.create!(endeavor: @endeavor, minutes_revision_id: meeting["revision_id"], record_key: item["key"], source_ids: selected_ids)
          end
        end
        @endeavor.history_events.create!(action: "published", endeavor_history_run: @run,
          metadata: { "edition_id" => edition.id, "sha256" => edition.sha256, "actor" => "automatic" })
        @run.update!(status: "succeeded", finished_at: Time.current)
      end
    end

    def finish_failure(category)
      @run.reload
      return if @run.terminal?
      @run.update!(status: category == "source_changed" ? "superseded" : "failed", error_category: category, finished_at: Time.current)
    end
  end
end
