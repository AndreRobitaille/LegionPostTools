module WebsitePublicationsHelper
  def website_event_start(snapshot)
    return legion_date(Date.iso8601(snapshot["starts_on"])) if snapshot["all_day"]

    legion_datetime(Time.iso8601(snapshot["starts_at"]).in_time_zone)
  end

  def website_event_end(snapshot)
    if snapshot["ends_on_exclusive"]
      legion_date(Date.iso8601(snapshot["ends_on_exclusive"]) - 1)
    elsif snapshot["ends_at"]
      legion_datetime(Time.iso8601(snapshot["ends_at"]).in_time_zone)
    else
      "No end specified"
    end
  end
end
