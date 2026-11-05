require_relative "endeavor_history_provider"

class SharedEndeavorHistoryTestProvider < EndeavorHistoryTestProvider
  def call(stage:, input:, schema:)
    return super unless stage == "shared_discovery"
    @calls << [ stage, input ]
    data = { "endeavors" => input.fetch("endeavors").map do |target|
      titles = case target["title"]
      when "Car Show" then [ "Finance report", "Car Show update", "Car Show" ]
      when "Picnic" then [ "Finance report" ]
      else []
      end
      { "endeavor_id" => target.fetch("id"), "items" => input.fetch("source").fetch("items").map do |item|
        relevant = titles.include?(item.fetch("title"))
        units = item.fetch("units").reject { |unit| unit["kind"] == "title" }
        { "key" => item.fetch("key"), "relevance" => relevant ? "related" : "no_match", "reason" => "Synthetic expected association.",
          "facts" => relevant ? units.map { |unit| { "text" => unit.fetch("text"), "kind" => "report", "source_ids" => [ unit.fetch("id") ] } } : [],
          "outcomes" => units.select { |unit| unit["kind"] == "outcome" }.map do |unit|
            { "source_id" => unit.fetch("id"), "relevant" => relevant, "reason" => "Synthetic expected outcome coverage." }
          end }
      end }
    end }
    @alter&.call(stage, input, data)
    { "data" => data, "total_tokens" => 10, "input_tokens" => 5, "output_tokens" => 5, "model" => "offline-fake" }
  end
end
