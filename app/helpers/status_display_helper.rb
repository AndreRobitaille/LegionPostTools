module StatusDisplayHelper
  def membership_status_tag(status)
    return "" if status.blank?

    text = ERB::Util.html_escape(status.to_s)
    variant =
      case status.to_s.strip.downcase
      when "active" then "st--active"
      when "expired" then "st--expired"
      else "st--other"
      end

    tag.span(class: "st #{variant}") do
      tag.span("", class: "st-dot") + text
    end
  end

  def agenda_active_tag(active)
    variant = active ? "st--active" : "st--other"
    label = active ? "Active" : "Inactive"

    tag.span(class: "st #{variant}") do
      tag.span("", class: "st-dot") + label
    end
  end
end
