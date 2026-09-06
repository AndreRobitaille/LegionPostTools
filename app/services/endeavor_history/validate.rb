module EndeavorHistory
  module Validate
    module_function

    def discovery!(data, source)
      entries = data.fetch("items")
      raise Error, "coverage" unless entries.is_a?(Array) && entries.map { |item| item["key"] } == source.fetch("items").map { |item| item["key"] }
      entries.zip(source.fetch("items")).each do |entry, item|
        raise Error, "ambiguous" if entry["relevance"] == "ambiguous"
        raise Error, "invalid_output" unless %w[related no_match].include?(entry["relevance"])
        if source["target_endeavor_id"] && item["primary_endeavor_id"] == source["target_endeavor_id"] && item["units"].any? && entry["relevance"] != "related"
          raise Error, "coverage"
        end
        facts = entry.fetch("facts")
        raise Error, "coverage" unless facts.is_a?(Array) && (entry["relevance"] == "related" || facts.empty?)
        allowed = item.fetch("units").map { |unit| unit.fetch("id") }
        facts.each do |fact|
          text!(fact.fetch("text"))
          references!(fact.fetch("source_ids"), allowed)
          raise Error, "invalid_output" unless %w[report proposal decision commitment uncertainty discrepancy].include?(fact["kind"])
        end
        outcomes = item.fetch("units").select { |unit| unit["kind"] == "outcome" }.map { |unit| unit["id"] }
        assessments = entry.fetch("outcomes")
        raise Error, "coverage" unless assessments.is_a?(Array) && assessments.map { |assessment| assessment["source_id"] }.sort == outcomes.sort
        assessments.each do |assessment|
          text!(assessment.fetch("reason"))
          raise Error, "invalid_output" unless [ true, false ].include?(assessment["relevant"])
          cited = facts.any? { |fact| fact["source_ids"].include?(assessment["source_id"]) }
          if assessment["relevant"] != cited
            raise Error, "coverage"
          end
        end
        raise Error, "coverage" if entry["relevance"] == "related" && allowed.any? && facts.empty?
      end
      data
    rescue KeyError, TypeError, NoMethodError
      raise Error, "invalid_output"
    end

    def summary!(data, meetings)
      expected = meetings.select { |meeting| meeting.fetch("facts").any? }
      actual = data.fetch("meetings")
      raise Error, "coverage" unless actual.is_a?(Array) && actual.map { |entry| entry["revision_id"] } == expected.map { |meeting| meeting["revision_id"] }
      expected.zip(actual).each do |meeting, entry|
        fact_ids = meeting.fetch("facts").map { |fact| fact["id"] }
        claims!([ entry.fetch("headline") ], fact_ids)
        raise Error, "invalid_output" if entry["headline"]["text"].length > 100
        outcome_ids = meeting.fetch("facts").flat_map { |fact| fact["source_ids"] }.uniq &
          meeting.fetch("items").flat_map { |item| item["units"].select { |unit| unit["kind"] == "outcome" }.pluck("id") }
        titles = entry.fetch("decision_titles")
        raise Error, "coverage" unless titles.is_a?(Array) && titles.map { |title| title["source_id"] }.sort == outcome_ids.sort
        titles.each do |title|
          text!(title.fetch("text"))
          raise Error, "invalid_output" if title["text"].length > 100
        end
        claims!(entry.fetch("claims"), fact_ids)
        used = entry.fetch("claims").flat_map { |claim| claim["fact_ids"] }
        raise Error, "coverage" unless (fact_ids - used).empty?
      end
      all_ids = expected.flat_map { |meeting| meeting.fetch("facts").map { |fact| fact["id"] } }
      claims!(data.fetch("overview"), all_ids)
      raise Error, "coverage" if all_ids.any? && data["overview"].empty?
      data
    rescue KeyError, TypeError, NoMethodError
      raise Error, "invalid_output"
    end

    def verification!(data, allowed)
      raise Error, "invalid_output" unless [ true, false ].include?(data.fetch("valid")) && data.fetch("issues").is_a?(Array)
      data["issues"].each do |issue|
        text!(issue.fetch("message"))
        ids = issue.fetch("source_ids")
        raise Error, "invalid_citation" unless ids.is_a?(Array) && (ids - allowed).empty?
      end
      raise Error, "verification_failed" unless data["valid"] && data["issues"].empty?
      data
    rescue KeyError, TypeError, NoMethodError
      raise Error, "invalid_output"
    end

    def claims!(claims, allowed)
      raise Error, "invalid_output" unless claims.is_a?(Array)
      claims.each do |claim|
        text!(claim.fetch("text"))
        references!(claim.fetch("fact_ids"), allowed)
      end
    end

    def text!(value)
      raise Error, "invalid_output" unless value.is_a?(String) && value.strip.present? && value.length <= 12000
    end

    def references!(ids, allowed)
      raise Error, "invalid_citation" unless ids.is_a?(Array) && ids.any? && ids.uniq == ids && (ids - allowed).empty?
    end
  end
end
