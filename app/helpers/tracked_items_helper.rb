module TrackedItemsHelper
  def tracked_item_status_tag(tracked_item)
    class_name = tracked_item.completed? ? "tracked-status tracked-status--completed" : "tracked-status"
    content_tag(:span, TrackedItem::STATUSES.fetch(tracked_item.status), class: class_name)
  end

  def tracked_item_priority_reason(tracked_item)
    parts = []
    parts << "Important post business" if tracked_item.important?
    if tracked_item.raise_by_on.present?
      prefix = tracked_item.raise_by_on < Date.current ? "Overdue since" : "Raise by"
      parts << "#{prefix} #{legion_date(tracked_item.raise_by_on)}"
    end
    parts.presence&.join(" · ") || "No raise-by date"
  end
end
