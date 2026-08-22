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

  def legion_date_parts(value)
    return [] if value.blank?

    date = value.to_date
    [ date.strftime("%d"), date.strftime("%b").upcase, date.strftime("%Y") ]
  end

  def parse_legion_date(string)
    normalized = string.to_s.strip
    return nil if normalized.empty?

    Date.strptime(normalized, "%d %b %Y")
  rescue ArgumentError
    nil
  end

  # Recombines the two halves of shared/_datetime_field back into one Time.
  # Returns nil when the date is missing or unparseable, so the model's own
  # presence validation reports the problem rather than a silent default.
  def combine_legion_datetime(date_string, time_string)
    date = parse_legion_date(date_string)
    time = /\A(?<hour>[01]\d|2[0-3]):(?<minute>[0-5]\d)\z/.match(time_string.to_s.strip)
    return nil if date.nil? || time.nil?

    Time.zone.local(date.year, date.month, date.day, time[:hour].to_i, time[:minute].to_i)
  end
end
