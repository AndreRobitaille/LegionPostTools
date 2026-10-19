module MinutesDistribution::Document
  module_function

  def context(minutes)
    approval = minutes.membership_approval
    organization = minutes.organization
    {
      "status" => minutes.membership_approved? ? "membership_approved" : "attested",
      "organization" => organization.attributes.slice("name", "locality", "mailing_address", "public_email"),
      "approval" => approval && {
        "disposition_label" => approval.disposition_label,
        "meeting_title" => approval.approving_meeting.title,
        "starts_at" => approval.approving_meeting.starts_at.iso8601
      }
    }
  end

  # Supply the existing officer PDF partial with a fixed document, never live working rows.
  def minutes(issue)
    copy = issue.meeting_minutes.dup
    copy.id = issue.meeting_minutes_id
    copy.status = issue.document_context.fetch("status")
    copy.current_revision = issue.minutes_revision
    copy.define_singleton_method(:pending_correction_approval) { nil }
    approval = issue.document_context["approval"]
    approval_copy = if approval
      Struct.new(:disposition_label, :approving_meeting).new(
        approval.fetch("disposition_label"),
        Struct.new(:title, :starts_at).new(approval.fetch("meeting_title"), Time.zone.parse(approval.fetch("starts_at")))
      )
    end
    copy.define_singleton_method(:membership_approval) { approval_copy }
    copy
  end

  def organization(issue)
    Organization.new(issue.document_context.fetch("organization").merge(
      unit_type: issue.organization.unit_type, timezone: issue.organization.timezone
    ))
  end
end
