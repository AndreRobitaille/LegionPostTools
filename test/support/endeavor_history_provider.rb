class EndeavorHistoryTestProvider
  attr_reader :calls
  attr_accessor :alter

  def initialize
    @calls = []
  end

  def call(stage:, input:, schema:)
    @calls << [ stage, input ]
    data = case stage
    when "discovery"
      { "items" => input.fetch("source").fetch("items").map do |item|
        units = item.fetch("units").reject { |unit| unit["kind"] == "title" }
        relevant = item["title"] != "Unrelated report"
        { "key" => item["key"], "relevance" => relevant ? "related" : "no_match", "reason" => "Source matches the named event.",
          "facts" => relevant ? units.map { |unit| { "text" => unit["text"], "kind" => "report", "source_ids" => [ unit["id"] ] } } : [],
          "outcomes" => units.select { |unit| unit["kind"] == "outcome" }.map { |unit| { "source_id" => unit["id"], "relevant" => relevant, "reason" => "Recorded event decision." } } }
      end }
    when "summary"
      meetings = input.fetch("meetings").select { |meeting| meeting["facts"].any? && (!input["account_revision_ids"] || input["account_revision_ids"].include?(meeting["revision_id"])) }.map do |meeting|
        { "revision_id" => meeting["revision_id"], "headline" => { "text" => "Volunteer needs and recorded decisions", "fact_ids" => [ meeting["facts"].first["id"] ] },
          "decision_titles" => meeting["items"].flat_map { |item| item["units"].select { |unit| unit["kind"] == "outcome" }.map { |unit| { "source_id" => unit["id"], "text" => "Fund allocation" } } },
          "claims" => meeting["facts"].map { |fact| { "text" => fact["text"], "fact_ids" => [ fact["id"] ] } } }
      end
      { "overview" => input["meetings"].flat_map { |meeting| meeting["facts"].map { |fact| { "text" => fact["text"], "fact_ids" => [ fact["id"] ] } } }.first(2), "meetings" => meetings }
    else
      { "valid" => true, "issues" => [] }
    end
    @alter&.call(stage, input, data)
    { "data" => data, "total_tokens" => 10, "input_tokens" => 5, "output_tokens" => 5, "model" => "offline-fake" }
  end
end
