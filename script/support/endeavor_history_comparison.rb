require "bigdecimal"

module EndeavorHistoryComparison
  # Private, exclusively locked ledger. Unknown costs keep their full reservation.
  # Prices: standard, short-context list prices, verified 2026-11-05.
  class Ledger
    RATES = { "gpt-6-astra" => [ 10, 50, 1 ], "gpt-6.1-sol" => [ 2, 10, 0.1 ] }.freeze
    attr_accessor :label
    attr_reader :state

    def initialize(path:, ceiling:)
      @file = File.open(path, File::RDWR | File::CREAT, 0600)
      raise "Ledger in use" unless @file.flock(File::LOCK_EX | File::LOCK_NB)
      File.chmod(0600, path)
      contents = @file.read
      @state = contents.empty? ? { "ceiling" => ceiling.to_s, "steps" => [], "runs" => {} } : JSON.parse(contents)
      raise "Cannot change an existing budget" unless BigDecimal(@state.fetch("ceiling")) == BigDecimal(ceiling.to_s)
      raise "Invalid budget" unless BigDecimal(@state.fetch("ceiling")).positive?
      persist
    rescue StandardError
      @file&.close
      raise
    end

    def charged
      @state.fetch("steps").sum(BigDecimal("0")) { |step| BigDecimal(step.fetch("charged").to_s) }
    end

    def record_run(label, result)
      @state.fetch("runs")[label] = result
      persist
    end

    def call(responses, params)
      rates = RATES.fetch(params.fetch(:model))
      raise "Explicit no-write caching required" unless params[:prompt_cache_options] == { mode: :explicit }
      # One token per serialized byte plus framing allowance is deliberately generous.
      input_bound = JSON.generate(params).bytesize + 4096
      raise "Only short context is priced" if input_bound > 272_000
      reserved = (BigDecimal(input_bound.to_s) * rates[0] + params.fetch(:max_output_tokens) * rates[1]) / 1_000_000
      raise EndeavorHistory::Error, "evaluation_budget" if charged + reserved > BigDecimal(@state.fetch("ceiling"))
      step = { "label" => label, "at" => Time.current.iso8601, "request" => params,
        "charged" => reserved.to_s("F"), "reserved" => true }
      @state.fetch("steps") << step
      persist # Must reach disk before making the request.
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = responses.create(**params.merge(service_tier: :default))
      step["response"] = response.to_h
      step["request_id"] = response._request_id
      usage = response.usage
      if usage && usage.total_tokens.to_i.positive? && usage.input_tokens_details&.cache_write_tokens.to_i.zero?
        cached = usage.input_tokens_details&.cached_tokens.to_i
        cost = (BigDecimal((usage.input_tokens - cached).to_s) * rates[0] +
          BigDecimal(cached.to_s) * rates[2].to_s.to_d + usage.output_tokens * rates[1]) / 1_000_000
        step.merge!("charged" => cost.to_s("F"), "reserved" => false)
      end
      response
    rescue StandardError => error
      step["error"] = error.class.name if step
      raise
    ensure
      if step
        step["seconds"] = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started if started
        persist
        puts({ event: "usage", label: label, calls: @state["steps"].size, charged_dollars: charged.to_s("F"),
          reserved: step["reserved"] }.to_json)
      end
    end

    def close
      @file.close unless @file.closed?
    end

    private

    def persist
      @file.rewind
      @file.write(JSON.pretty_generate(@state))
      @file.truncate(@file.pos)
      @file.flush
      @file.fsync
    end
  end

  class Provider < EndeavorHistory::Provider
    Client = Struct.new(:responses)
    Responses = Struct.new(:delegate, :ledger) do
      def create(**params) = ledger.call(delegate, params)
    end

    def initialize(ledger:, **options)
      super(**options)
      @ledger = ledger
    end

    private

    def client
      @metered_client ||= Client.new(Responses.new(super.responses, @ledger))
    end
  end

  # Production algorithms with no Active Record reads/writes or publication.
  class Pipeline < EndeavorHistory::Processing
    NullStore = Class.new do
      def verified(*) = nil
      def comparison_candidate(*) = nil
      def save(*) = nil
    end

    def initialize(snapshot:, target:, provider:, shared: nil)
      @snapshot, @provider, @shared = snapshot, provider, shared
      @endeavor = Struct.new(:id).new(target.fetch("id"))
      @run = Struct.new(:id, :manifest).new(-target.fetch("id"), {
        "endeavor" => target.slice("id", "title", "summary"), "catalog" => snapshot.fetch("catalog"),
        "guidance_id" => target["guidance_id"], "generation" => target.fetch("generation") })
      @guidance = target.fetch("guidance")
      @request = { "refresh" => true }
      @shared_group = shared && { "id" => "evaluation", "targets" => snapshot.fetch("targets") }
      @reuse = NullStore.new
    end

    def call
      meetings = @snapshot.fetch("documents").map do |document|
        @request["shared_revision_id"] = document.fetch("revision_id")
        discover(document)
      end
      compose(meetings).merge("evidence" => meetings)
    end

    private

    def previous_edition = nil
    def ensure_current!; end

    def shared_discover(source)
      input = { "attestation_group_id" => "evaluation", "endeavors" => @shared_group.fetch("targets"),
        "catalog" => @run.manifest.fetch("catalog"), "source" => source.except("target_endeavor_id") }
      key = EndeavorHistory::Sources.digest(input)
      result = @shared[key] ||= generate_verified("shared_discovery", input, EndeavorHistory::Schemas.shared_discovery) do |data|
        EndeavorHistory::Validate.shared_discovery!(data, input)
      end
      result.fetch("endeavors").find { |entry| entry.fetch("endeavor_id") == @endeavor.id }
    end

    def invoke(stage, input, schema, **)
      @provider.call(stage: stage, input: input, schema: schema).fetch("data")
    end
  end

  def self.run(snapshot:, ledger:, label:, mode:, provider: Provider.new(ledger: ledger))
    raise "Unknown mode" unless %w[shared baseline].include?(mode)
    raise "Label already recorded; inspect it instead of replaying" if ledger.state.fetch("runs").key?(label)
    ledger.label = label
    result = { "status" => "running", "mode" => mode, "snapshot" => snapshot,
      "snapshot_digest" => EndeavorHistory::Sources.digest(snapshot), "configuration" => EndeavorHistory::Config.signature,
      "histories" => {} }
    ledger.record_run(label, result)
    shared = mode == "shared" ? {} : nil
    snapshot.fetch("targets").each do |target|
      result["histories"][target.fetch("id").to_s] = Pipeline.new(snapshot: snapshot, target: target, provider: provider, shared: shared).call
      ledger.record_run(label, result)
    end
    result["status"] = "succeeded"
    ledger.record_run(label, result)
    result
  rescue StandardError => error
    if result
      result.merge!("status" => "failed", "error" => error.respond_to?(:category) ? error.category : error.class.name)
      ledger.record_run(label, result)
    end
    raise
  end
end
