module EndeavorHistory
  class Reuse
    LEGACY_CONFIGURATION = {
      "model" => "gpt-6-astra", "normalization_version" => "1", "prompt_version" => "endeavor-astra-2",
      "prompt_digest" => "becb6aeefd7ddde923c66559d6aaf8e9eb8c28616535514553cc7a5f7cf70706",
      "reasoning" => { "discovery" => "high", "verify_discovery" => "high", "summary" => "medium", "verify_summary" => "high" }
    }.freeze

    def initialize(run)
      @run = run
    end

    def fingerprint(stage, input)
      Sources.digest({ "stage" => stage, "input" => input.except("refresh_id"), "policy" => Prompt.policy_digest(stage) })
    end

    def verified(stage, input)
      results.where(stage: stage, fingerprint: fingerprint(stage, input)).order(id: :desc).detect do |result|
        (!input["refresh_id"] || result.input["refresh_id"] == input["refresh_id"]) && compatible_verifier?(result, stage)
      end
    end

    # A changed comparison catalog requires another complete-source audit, not
    # unconditional regeneration of previously verified facts and dated prose.
    def comparison_candidate(input)
      results.where(stage: "discovery").order(id: :desc).detect do |result|
        result.configuration["policy_digest"] == Prompt.policy_digest("discovery") &&
          (!input["refresh_id"] || result.input["refresh_id"] == input["refresh_id"]) &&
          result.input.except("catalog", "refresh_id") == input.except("catalog", "refresh_id")
      end
    end

    def save(stage, input, candidate, verification)
      results.create!(endeavor_history_run: @run, stage: stage, fingerprint: fingerprint(stage, input),
        input: input, candidate: candidate, verification: verification, configuration: Config.signature.merge("policy_digest" => Prompt.policy_digest(stage)))
    end

    def completed_call(stage, input)
      digest = Sources.digest(input)
      configuration = Sources.digest(Config.stage_signature(stage))
      @run.endeavor.history_runs.where.not(id: @run.id).order(id: :desc).each do |run|
        run.steps.reverse_each do |step|
          next if step["reused"] || !step["data"]
          if step["stage"] == stage && step["input_sha256"] == digest && step["configuration_sha256"] == configuration
            return [ run, step ]
          end
        end
      end
      nil
    end

    # Existing editions remain under their original verification policy. Adoption
    # requires the actual complete coverage and the exact accepting verifier call;
    # a summary alone cannot manufacture evidence or negative coverage.
    def legacy_meeting(document)
      @run.endeavor.history_editions.includes(:endeavor_history_run).order(id: :desc).each do |edition|
        manifest = edition.manifest
        next unless Sources.identity(manifest) == Sources.identity(@run.manifest) && manifest["catalog"] == @run.manifest["catalog"]
        meeting = edition.payload.fetch("evidence").find { |entry| entry["revision_id"] == document["revision_id"] && entry["sha256"] == document["sha256"] }
        next unless meeting
        # A scoped repair must never fall back to an older legacy extraction.
        return nil if meeting["normalization_version"] == SourceDocument::VERSION
        if meeting["legacy_edition_id"]
          original = @run.endeavor.history_editions.find_by(id: meeting["legacy_edition_id"])
          return nil unless original && Sources.identity(original.manifest) == Sources.identity(manifest) && original.manifest["catalog"] == manifest["catalog"]
          original_meeting = original.payload.fetch("evidence").find { |entry| entry["revision_id"] == document["revision_id"] && entry["sha256"] == document["sha256"] }
          return nil unless original_meeting && original_meeting.slice("facts", "coverage") == meeting.slice("facts", "coverage")
          edition = original
          manifest = original.manifest
        end
        return nil unless manifest["configuration"] == LEGACY_CONFIGURATION
        revision = MinutesRevision.find(document["revision_id"])
        source = SourceDocument.new(revision, version: "1").payload.merge("target_endeavor_id" => @run.endeavor_id)
        guidance = @run.endeavor.history_guidances.find_by(id: manifest["guidance_id"])&.body.to_s
        input = { "endeavor" => manifest["endeavor"], "catalog" => manifest["catalog"], "guidance" => guidance, "source" => source }
        candidate = ordered({ "items" => meeting.fetch("coverage") }, Schemas.discovery)
        Validate.discovery!(candidate, source)
        return nil if legacy_requires_recheck?(candidate, source)
        steps = edition.endeavor_history_run.steps
        generation = steps.find { |step| step["stage"] == "discovery" && step["input_sha256"] == legacy_digest(input) && step["data"] == candidate }
        verification = steps.find { |step| step["stage"] == "verify_discovery" && step["input_sha256"] == legacy_digest(input.merge("candidate" => candidate)) }
        next unless generation && verification && verification["data"]
        Validate.verification!(verification["data"], source["items"].flat_map { |item| item["units"].pluck("id") })
        facts = candidate["items"].flat_map do |entry|
          entry["facts"].each_with_index.map { |fact, index| fact.merge("id" => "r#{document['revision_id']}:#{entry['key']}:fact:#{index}") }
        end
        next unless facts == meeting["facts"]
        return [ edition, meeting.merge("normalization_version" => "1", "legacy_edition_id" => edition.id) ]
      end
      nil
    rescue Error, KeyError
      nil
    end

    private

    def results = EndeavorHistoryResult.where(endeavor_id: @run.endeavor_id)

    def legacy_digest(value) = Digest::SHA256.hexdigest(JSON.generate(value))

    def compatible_verifier?(result, stage)
      verifier = "verify_#{stage}"
      model = result.configuration.dig("models", verifier) || result.configuration["model"]
      effort = result.configuration.dig("reasoning", verifier)
      (model == Config.model(verifier) && effort == Config.reasoning(verifier)) || (model == "gpt-6-astra" && effort == "high")
    end

    def legacy_requires_recheck?(candidate, source)
      candidate["items"].zip(source["items"]).any? do |entry, item|
        next false unless entry["relevance"] == "related" || item["primary_endeavor_id"] == @run.endeavor_id
        dated = Validate.dated_title?(item["title"])
        financial = entry["outcomes"].any? { |outcome| outcome["relevant"] } &&
          item["units"].any? { |unit| unit["text"].match?(/\bCD\b|certificate of deposit|\bmatur|\broll(?:s|ed|ing)?\s*over/i) }
        dated || financial
      end
    end

    # JSONB does not retain key order. Historical input hashes used the strict
    # response schema's field order; restore that order when checking provenance.
    def ordered(value, schema)
      case schema[:type]
      when "object"
        schema.fetch(:properties).to_h { |key, child| [ key.to_s, ordered(value.fetch(key.to_s), child) ] }
      when "array"
        value.map { |entry| ordered(entry, schema.fetch(:items)) }
      else
        value
      end
    end
  end
end
