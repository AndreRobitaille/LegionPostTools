module MinutesDrafting
  class Prompt
    VERSION = "minutes-first-pass-v5"
    SCHEMA_VERSION = "minutes-suggestions-v2"

    DEVELOPER_PROMPT = <<~PROMPT.freeze
      You prepare cautious working suggestions for American Legion meeting minutes.
      You do not create an official record and you do not decide what happened. A human Adjutant reviews every suggestion.

      Use only the supplied meeting, structured agenda/minutes outline, and numbered transcript source. Never use outside knowledge.
      Do not infer a speaker, mover, seconder, attendance status, vote, disposition, spelling, title, or identity from likelihood.
      Do not match a transcript name to a person merely because the names look similar.
      When a fact is missing or uncertain, omit that suggestion or record the uncertainty in missing_facts.
      Every suggestion must cite the smallest numbered source-line range that directly supports it.
      Do not suggest ceremonial script as discussion unless the transcript records a material departure or action.
      Write selectively complete, neutral minutes rather than a terse outline or a transcript. The result should let a member
      who was absent understand what happened, why it matters, and any concrete way to participate or follow up. Preserve
      material context, significant viewpoints or disagreement, reasons offered, proposals, decisions, next steps, deadlines,
      dates, places, costs, quantities, names, numbers, and statistics when the transcript directly supports them. Attribute a
      statement or viewpoint to a named person only when the source directly identifies that speaker. Omit repetition, minor
      banter, and conversational detours that do not help the future record.
      Apply a strict privacy exception to Sick Call and Service Officer reports. Never include a person's name or identifying
      health, benefits, financial, or case details from those reports. Record only anonymous or aggregate counts and general
      activity needed for the meeting record. Do not move those private details into another agenda item to preserve them.
      Assign each suggestion to the agenda subject where it belongs, regardless of when it appears in the transcript.
      In particular, place an officer report under that officer's matching report item even when the report was given out of order.
      If substantive discussion strays from the current item, use a more specific matching agenda item when one exists.
      If no agenda item fits, check available_endeavors before treating the discussion as unrelated. When one clearly matches,
      propose an additional_item with that exact endeavor_id; never infer or invent an Endeavor id. Otherwise use the existing
      Good of The American Legion item, or propose an additional_item in its section. Keep citations at the actual transcript
      lines even when the target appears earlier or later in the agenda. Omit a brief aside or flag missing_facts when routing is uncertain.
      Prefer one consolidated item_summary per target. If one agenda item contains clearly distinct proceedings,
      you may return separate item_summary suggestions; the app will review and append each paragraph independently.
      A motion or decision suggestion requires direct transcript support. Use not_recorded for an unknown disposition.
      Preserve a spoken mover or seconder name only as the transcript states it; never expand a first name, nickname, or uncertain
      spelling. Human reviewers will resolve identities from the Post roster in a later workflow.
      Never suggest Commander approval, Adjutant attestation, membership approval, amendment, or any change to an Endeavor.

      target_id means: MinutesItem id for item_summary/outcome, MinutesAttendanceEntry id for attendance,
      and MinutesSection id for additional_item. Use only ids present in the supplied outline.
      source_agenda_item_id is the supplied agenda item id when the suggestion belongs to one; otherwise null.
      endeavor_id is allowed only for additional_item and must be an exact id from available_endeavors; otherwise it is null.
    PROMPT

    class << self
      def sha256 = Digest::SHA256.hexdigest(DEVELOPER_PROMPT)

      def input(minutes:, source_document:)
        JSON.generate(
          meeting: {
            title: minutes.title,
            starts_at: minutes.starts_at.iso8601,
            location_name: minutes.location_name
          },
          outline: minutes.sections.includes(items: [ :source_dated_agenda_item, :rich_text_agenda_body, :rich_text_body ]).map do |section|
            {
              minutes_section_id: section.id,
              title: section.title,
              items: section.items.map do |item|
                {
                  minutes_item_id: item.id,
                  source_agenda_item_id: item.source_dated_agenda_item_id,
                  title: item.title,
                  behavior_type: item.behavior_type,
                  confirmed_endeavor_id: item.endeavor_id,
                  agenda_wording: item.agenda_body.present? ? item.agenda_body.to_plain_text : nil,
                  existing_minutes: item.body.present? ? item.body.to_plain_text : nil
                }
              end
            }
          end,
          attendance: minutes.attendance_entries.map do |entry|
            {
              minutes_attendance_entry_id: entry.id,
              office_name: entry.office_name,
              agenda_person_name: entry.person_name,
              current_status: entry.status
            }
          end,
          available_endeavors: available_endeavors(minutes).map do |endeavor|
            {
              endeavor_id: endeavor.id,
              title: endeavor.title,
              summary: endeavor.summary.presence,
              status: endeavor.status
            }
          end,
          numbered_transcript: source_document.rendered
        )
      end

      def available_endeavors(minutes)
        organization_endeavors = minutes.organization.endeavors
        active = organization_endeavors.active
        completed_after_meeting = organization_endeavors.completed.where(completed_at: minutes.starts_at..)

        active.or(completed_after_meeting).order(:title, :id)
      end

      def schema
        {
          type: "object",
          additionalProperties: false,
          required: [ "suggestions" ],
          properties: {
            suggestions: {
              type: "array",
              maxItems: 500,
              items: suggestion_schema
            }
          }
        }
      end

      private

      def suggestion_schema
        nullable_string = { type: [ "string", "null" ] }
        {
          type: "object",
          additionalProperties: false,
          required: %w[
            kind target_id source_agenda_item_id endeavor_id title body outcome_kind disposition
            mover_name seconder_name vote_summary attendance_status source_start_line
            source_end_line confidence missing_facts
          ],
          properties: {
            kind: { type: "string", enum: MinutesDraftSuggestion::KINDS },
            target_id: { type: [ "integer", "null" ] },
            source_agenda_item_id: { type: [ "integer", "null" ] },
            endeavor_id: { type: [ "integer", "null" ] },
            title: nullable_string,
            body: nullable_string,
            outcome_kind: { type: [ "string", "null" ], enum: MinutesOutcome::KINDS + [ nil ] },
            disposition: { type: [ "string", "null" ], enum: MinutesOutcome::DISPOSITIONS + [ nil ] },
            mover_name: nullable_string,
            seconder_name: nullable_string,
            vote_summary: nullable_string,
            attendance_status: { type: [ "string", "null" ], enum: MinutesAttendanceEntry::STATUSES + [ nil ] },
            source_start_line: { type: "integer", minimum: 1 },
            source_end_line: { type: "integer", minimum: 1 },
            confidence: { type: "string", enum: MinutesDraftSuggestion::CONFIDENCES },
            missing_facts: { type: "array", items: { type: "string" }, maxItems: 20 }
          }
        }
      end
    end
  end
end
