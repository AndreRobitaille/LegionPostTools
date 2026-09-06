# Explicitly authorized live evaluation only:
# bin/rails runner script/evaluate_endeavor_history.rb SNAPSHOT EFFORT ENDEAVOR_ID OUTPUT
# No database writes: reuse the production extraction/verification methods with file output.
class EndeavorReasoningEvaluation < EndeavorHistory::Processing
  def initialize(snapshot:, effort:, endeavor_id:, output:)
    raise ArgumentError, "Use low, medium, or mixed" unless %w[low medium mixed].include?(effort)
    raise "Prompt differs from snapshot" unless snapshot.fetch("prompt_digest") == EndeavorHistory::Prompt.digest
    @snapshot = snapshot
    @case = snapshot.fetch("cases").find { |entry| entry.dig("endeavor", "id") == endeavor_id } or raise "Unknown Endeavor"
    @run = Struct.new(:manifest).new(@case.fetch("manifest"))
    @endeavor = Struct.new(:id).new(endeavor_id)
    @guidance = @case.fetch("guidance")
    @output = output
    @steps = []
    @provider = EndeavorHistory::Provider.new
    @effort = effort
    %w[discovery verify_discovery summary verify_summary].each do |stage|
      level = effort
      level = stage.start_with?("verify_") ? "high" : "medium" if effort == "mixed"
      ENV["OPENAI_ENDEAVOR_#{stage.upcase}_REASONING"] = level
    end
  end

  def call
    @started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    meetings = @snapshot.fetch("documents").map { |document| discover(document) }
    input = { "endeavor" => @case.fetch("endeavor"), "guidance" => @guidance, "meetings" => meetings }
    summary = if meetings.any? { |meeting| meeting.fetch("facts").any? }
      generate_verified("summary", input, EndeavorHistory::Schemas.summary) { |data| EndeavorHistory::Validate.summary!(data, meetings) }
    else
      { "overview" => [], "meetings" => [] }
    end
    save("succeeded", payload: summary.merge("evidence" => meetings))
  rescue EndeavorHistory::Error => error
    save("failed", error: error.category)
  end

  private

  def invoke(stage, input, schema)
    raise EndeavorHistory::Error, "call_budget" if @steps.size >= 16
    raise EndeavorHistory::Error, "input_limit" if JSON.generate(input).bytesize > EndeavorHistory::Config.max_input_bytes
    puts({ event: "call", endeavor: @endeavor.id, effort: @effort, stage: stage }.to_json)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = @provider.call(stage: stage, input: input, schema: schema)
    @steps << result.merge("stage" => stage, "reasoning" => EndeavorHistory::Config.reasoning(stage),
      "seconds" => Process.clock_gettime(Process::CLOCK_MONOTONIC) - started)
    save("running")
    result.fetch("data")
  end

  def save(status, **extra)
    result = { status: status, endeavor_id: @endeavor.id, effort: @effort, steps: @steps,
      prompt_digest: @snapshot.fetch("prompt_digest"), snapshot_digest: EndeavorHistory::Sources.digest(@snapshot),
      elapsed_seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started }.merge(extra)
    File.write(@output, JSON.pretty_generate(result), perm: 0600)
    puts({ event: status, endeavor: @endeavor.id, effort: @effort, calls: @steps.size,
      tokens: @steps.sum { |s| s.fetch("total_tokens") }, error: extra[:error] }.to_json)
  end
end

$stdout.sync = true
snapshot_path, effort, endeavor_id, output = ARGV
abort "Usage: SNAPSHOT low|medium|mixed ENDEAVOR_ID OUTPUT" unless ARGV.size == 4
raise "Output already exists" if File.exist?(output)
EndeavorReasoningEvaluation.new(snapshot: JSON.parse(File.read(snapshot_path)), effort: effort,
  endeavor_id: Integer(endeavor_id), output: output).call
