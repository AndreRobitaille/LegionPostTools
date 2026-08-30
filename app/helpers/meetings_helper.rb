module MeetingsHelper
  def meeting_record_state(meeting)
    agenda = meeting.dated_agenda
    return [ "Agenda not started", "meeting-state--quiet" ] if agenda.nil?

    [ "#{agenda.status.humanize} agenda", "meeting-state--#{agenda.status}" ]
  end

  def member_meeting_state(meeting)
    if meeting.dated_agenda&.published?
      [ "Agenda published", "meeting-state--published" ]
    elsif meeting.starts_at < Time.zone.today.beginning_of_day
      [ "No agenda was published", "meeting-state--quiet" ]
    else
      [ "Agenda not published yet", "meeting-state--quiet" ]
    end
  end

  def admin_meeting_action(meeting)
    agenda = meeting.dated_agenda
    return "Prepare agenda" if agenda.nil?
    return "Continue agenda" if agenda.draft?
    return "Open published agenda" if agenda.published?

    "Open agenda"
  end
end
