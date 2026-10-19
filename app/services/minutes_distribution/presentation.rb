module MinutesDistribution::Presentation
  module_function

  def post_label(organization)
    if organization.unit_type == "american_legion_post" && organization.unit_number.present?
      "Post #{organization.unit_number}"
    else
      organization.name
    end
  end

  def meeting_name(name)
    name.to_s.sub(/\s+meeting\z/i, "").presence || name.to_s
  end

  def status(approved:, body_name:)
    body = meeting_name(body_name)
    body = "membership" if body.casecmp?("Membership")
    if approved
      { "label" => "Attested and approved", "note" => "Attested by the Adjutant and approved by the #{body}." }
    else
      { "label" => "Attested — awaiting #{body} approval",
        "note" => "Attested by the Adjutant. Corrections may be made at the next #{body} meeting." }
    end
  end
end
