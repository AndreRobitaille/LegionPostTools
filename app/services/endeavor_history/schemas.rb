module EndeavorHistory
  module Schemas
    module_function

    def object(properties)
      { type: "object", properties: properties, required: properties.keys, additionalProperties: false }
    end

    def array(item) = { type: "array", items: item }
    def string = { type: "string" }
    def ids = array(string)

    def discovery
      object(items: array(object(
        key: string, relevance: { type: "string", enum: %w[related no_match ambiguous] }, reason: string,
        facts: array(object(text: string, kind: { type: "string", enum: %w[report proposal decision commitment uncertainty discrepancy] }, source_ids: ids)),
        outcomes: array(object(source_id: string, relevant: { type: "boolean" }, reason: string))
      )))
    end

    def summary
      claim = object(text: string, fact_ids: ids)
      object(overview: array(claim), meetings: array(object(revision_id: { type: "integer" }, headline: claim,
        decision_titles: array(object(source_id: string, text: string)), claims: array(claim))))
    end

    def verification
      object(valid: { type: "boolean" }, issues: array(object(message: string, source_ids: ids)))
    end
  end
end
