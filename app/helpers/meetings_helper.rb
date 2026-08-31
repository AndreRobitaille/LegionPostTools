module MeetingsHelper
  def meeting_record_state(meeting)
    if internal_minutes_access?
      if meeting.minutes
        label = meeting.minutes.attested? ? "Minutes awaiting acceptance" : "#{meeting.minutes.status.humanize} minutes"
        return [ label, "meeting-state--minutes" ]
      end
      return [ "Transcript ready", "meeting-state--transcript" ] if meeting.transcript
    end

    agenda_record_state(meeting)
  end

  def agenda_record_state(meeting)
    agenda = meeting.dated_agenda
    return [ "Agenda not started", "meeting-state--quiet" ] if agenda.nil?

    [ "#{agenda.status.humanize} agenda", "meeting-state--#{agenda.status}" ]
  end

  def member_meeting_state(meeting)
    if meeting.minutes&.attested?
      return [ "Minutes awaiting acceptance", "meeting-state--minutes" ]
    end

    if meeting.dated_agenda&.published?
      [ "Agenda published", "meeting-state--published" ]
    elsif meeting.starts_at < Time.zone.today.beginning_of_day
      [ "No agenda was published", "meeting-state--quiet" ]
    else
      [ "Agenda not published yet", "meeting-state--quiet" ]
    end
  end

  def revision_outcome_label(disposition)
    {
      "adopted" => "Passed",
      "lost" => "Did not pass",
      "withdrawn" => "Withdrawn",
      "postponed" => "Postponed",
      "referred" => "Referred",
      "no_vote" => "No vote taken",
      "not_recorded" => "Not recorded"
    }.fetch(disposition, disposition.to_s.humanize)
  end

  def admin_meeting_action(meeting)
    return "Open minutes" if meeting.minutes && internal_minutes_access?
    return "Begin minutes" if meeting.starts_at <= Time.current && current_user.can?("manage_minutes")

    agenda = meeting.dated_agenda
    return current_user.can?("manage_agendas") ? "Prepare agenda" : "Open record" if agenda.nil?
    return "Continue agenda" if agenda.draft?
    return "Open published agenda" if agenda.published?

    "Open agenda"
  end

  def internal_minutes_access?
    current_user.can_any?("manage_minutes", "view_internal_records")
  end
end
