module MinutesOutcomesHelper
  OTHER_MOTION_DISPOSITIONS = [
    [ "Withdrawn", "withdrawn" ],
    [ "Postponed", "postponed" ],
    [ "Referred", "referred" ],
    [ "No vote taken", "no_vote" ]
  ].freeze

  def minutes_outcome_disposition_label(disposition)
    {
      "adopted" => "Passed",
      "lost" => "Failed",
      "withdrawn" => "Withdrawn",
      "postponed" => "Postponed",
      "referred" => "Referred",
      "no_vote" => "No vote taken",
      "not_recorded" => "Needs review"
    }.fetch(disposition)
  end

  def minutes_outcome_result_group(disposition)
    return disposition if disposition.in?(%w[adopted lost])

    "other" if disposition.in?(OTHER_MOTION_DISPOSITIONS.map(&:last))
  end

  def minutes_review_disposition(values, fallback)
    submitted = values["disposition"]
    return values["other_disposition"] if submitted == "other"

    submitted.presence || fallback
  end

  def minutes_person_picker_data(people)
    people.map do |person|
      {
        id: person.id,
        name: person.full_name,
        search: [ person.full_name, person.roster_name ].compact_blank.join(" "),
        detail: person.current_role_label || person.roster_member_status.presence || "Post member"
      }
    end
  end
end
