module StatusDisplayHelper
  def membership_status_tag(status)
    return "" if status.blank?

    variant =
      case status.to_s.strip.downcase
      when "active" then "st--active"
      when "expired" then "st--expired"
      else "st--other"
      end

    tag.span(class: "st #{variant}") do
      tag.span("", class: "st-dot") + status.to_s
    end
  end
end
