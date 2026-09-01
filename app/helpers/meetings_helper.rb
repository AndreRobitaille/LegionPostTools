module MeetingsHelper
  def member_meeting_title(meeting)
    default_title = Meeting.default_title(
      meeting_body: meeting.meeting_body,
      meeting_type: meeting.meeting_type,
      starts_at: meeting.starts_at
    )

    meeting.title == default_title ? (meeting.meeting_type&.name.presence || meeting.meeting_body.name) : meeting.title
  end

  def member_meeting_document_action(meeting)
    if meeting.minutes&.attested?
      return {
        label: "View minutes",
        path: meeting_minutes_path(meeting),
        note: "Awaiting member acceptance",
        state: "minutes"
      }
    end

    if meeting.dated_agenda&.published?
      return {
        label: "View agenda",
        path: dated_agenda_path(meeting.dated_agenda),
        note: ("Minutes not available yet" if member_past_meeting?(meeting)),
        state: "agenda"
      }
    end

    if member_past_meeting?(meeting)
      { label: "No documents available", path: nil, note: nil, state: "unavailable" }
    else
      { label: "Agenda not published yet", path: nil, note: nil, state: "unavailable" }
    end
  end

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
    current_user.can_any?("manage_minutes", "approve_minutes", "attest_minutes", "view_internal_records")
  end

  private

  def member_past_meeting?(meeting)
    meeting.starts_at < Time.zone.today.beginning_of_day
  end
end
