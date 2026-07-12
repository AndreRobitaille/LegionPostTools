module LegionFormatHelper
  def legion_date(value)
    return "" if value.blank?

    value.to_date.strftime("%d %b %Y").upcase
  end

  def legion_time(value)
    return "" if value.blank?

    value.strftime("%H:%M")
  end

  def legion_datetime(value)
    return "" if value.blank?

    "#{legion_date(value)} · #{legion_time(value)}"
  end

  def parse_legion_date(string)
    normalized = string.to_s.strip
    return nil if normalized.empty?

    Date.strptime(normalized, "%d %b %Y")
  rescue ArgumentError
    nil
  end
end
