module Api
  class MemberMeetingDocumentsController < BaseController
    before_action :set_meeting
    before_action :set_agenda, only: %i[agenda agenda_print]
    before_action :set_minutes, only: %i[minutes minutes_print]
    after_action :prevent_private_data_caching

    def agenda
      render json: { agenda: member_agenda_summary_payload(@agenda).merge(
        sections: @agenda.dated_agenda_sections.ordered.map do |section|
          { title: section.title, position: section.position,
            items: section.agenda_items.active.order(:position, :title).map do |item|
              { title: item.title, position: item.position,
                wording: (item.body.to_plain_text.presence if item.show_wording_on_agenda?),
                summary: (item.summary.presence if item.body.blank?) }
            end }
        end
      ) }
    end

    def minutes
      render json: { minutes: member_minutes_summary_payload(@minutes, revision: @revision).merge(
        document: member_revision_document,
        attestation: {
          attested_by: @revision.attestation.attester_name,
          office: @revision.attestation.attester_office,
          attested_at: @revision.attestation.attested_at.iso8601
        },
        commander_handoff: (@revision.approved_by_id ? {
          name: @revision.approver_name, office: @revision.approver_office,
          handed_off_at: @revision.approved_at.iso8601
        } : nil),
        membership_approval: member_approval_payload
      ) }
    end

    def agenda_print
      send_data DatedAgendaPdf.render(dated_agenda: @agenda, variant: "agenda"),
        filename: DatedAgendaPdf.filename(dated_agenda: @agenda, variant: "agenda"),
        type: "application/pdf", disposition: "inline"
    rescue DatedAgendaPdf::GenerationError => error
      render_pdf_error(error)
    end

    def minutes_print
      send_data MeetingMinutesPdf.render(minutes: @minutes, revision: @revision),
        filename: MeetingMinutesPdf.filename(minutes: @minutes, revision: @revision),
        type: "application/pdf", disposition: "inline"
    rescue MeetingMinutesPdf::GenerationError => error
      render_pdf_error(error)
    end

    private

    def set_meeting
      @meeting = organization.meetings.find(params[:meeting_id])
    end

    def set_agenda
      @agenda = @meeting.dated_agenda
      raise ActiveRecord::RecordNotFound unless @agenda&.published?
    end

    def set_minutes
      @minutes = @meeting.minutes
      @revision = @minutes&.member_revision
      raise ActiveRecord::RecordNotFound unless @revision&.attestation
    end

    def member_revision_document
      payload = @revision.payload
      payload.slice("title", "starts_at", "location_name", "location_address", "meeting_body_name").merge(
        "attendance" => payload.fetch("attendance").map { |entry| entry.slice("office_name", "person_name", "status", "position") },
        "sections" => payload.fetch("sections").map do |section|
          section.slice("title", "position").merge("items" => section.fetch("items").map do |item|
            item.slice("record_key", "title", "behavior_type", "position").merge(
              "agenda_body_html" => helpers.document_rich_text(item["agenda_body_html"]).presence,
              "body_html" => helpers.document_rich_text(item["body_html"]).presence,
              "outcomes" => item.fetch("outcomes").map { |outcome| outcome.slice("kind", "text", "mover_name", "seconder_name", "disposition", "vote_summary", "position") }
            )
          end)
        end
      )
    end

    def member_approval_payload
      approval = @minutes.membership_approval
      return nil unless @minutes.membership_approved? && approval

      {
        disposition: approval.disposition, label: approval.disposition_label,
        approving_meeting_id: approval.approving_meeting_id,
        approving_meeting_title: approval.approving_meeting.title,
        approving_meeting_starts_at: approval.approving_meeting.starts_at.iso8601,
        recorder_name: approval.recorder_name, recorder_office: approval.recorder_office,
        factual_note: approval.factual_note
      }
    end

    def render_pdf_error(error)
      Rails.logger.error("Member API PDF generation failed: #{error.message}")
      render_error("The document PDF could not be created. Try again.", status: :service_unavailable)
    end
  end
end
