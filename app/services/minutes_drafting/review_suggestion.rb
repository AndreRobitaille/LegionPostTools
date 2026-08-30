module MinutesDrafting
  class ReviewSuggestion
    def self.call(suggestion:, reviewer:, action:, edits: {})
      new(suggestion:, reviewer:, action:, edits:).call
    end

    def initialize(suggestion:, reviewer:, action:, edits:)
      @suggestion = suggestion
      @reviewer = reviewer
      @action = action.to_s
      @edits = edits.to_h.stringify_keys
    end

    def call
      suggestion.with_lock do
        raise ActiveRecord::RecordInvalid, suggestion unless suggestion.unreviewed?

        if action == "discard"
          record_review!("discarded")
        elsif action.in?(%w[use edit])
          applied_record = apply_payload!(action == "edit" ? edited_payload : suggestion.payload)
          record_review!(action == "edit" ? "edited" : "used", applied_record)
        else
          raise ArgumentError, "Unknown review action"
        end
      end

      suggestion
    end

    private

    attr_reader :suggestion, :reviewer, :action, :edits

    def edited_payload
      allowed = case suggestion.kind
      when "item_summary" then %w[body]
      when "outcome" then %w[kind text disposition mover_name seconder_name vote_summary]
      when "attendance" then %w[status]
      when "additional_item" then %w[title body endeavor_id]
      end
      suggestion.payload.merge(edits.slice(*allowed)).compact
    end

    def apply_payload!(payload)
      case suggestion.kind
      when "item_summary"
        suggestion.minutes_item.tap { |item| append_item_body!(item, payload.fetch("body")) }
      when "outcome"
        item = suggestion.minutes_item
        item.outcomes.create!(
          kind: payload.fetch("kind"),
          text: payload.fetch("text"),
          disposition: payload.fetch("disposition"),
          mover_name: payload["mover_name"],
          seconder_name: payload["seconder_name"],
          vote_summary: payload["vote_summary"],
          position: item.outcomes.maximum(:position).to_i + 1
        )
      when "attendance"
        suggestion.minutes_attendance_entry.tap { |entry| entry.update!(status: payload.fetch("status")) }
      when "additional_item"
        section = suggestion.minutes_section
        endeavor = proposed_endeavor(payload)
        section.items.create!(
          title: payload.fetch("title"),
          body: payload.fetch("body"),
          behavior_type: "business_item",
          endeavor: endeavor,
          position: section.items.maximum(:position).to_i + 1
        )
      end
    end

    def proposed_endeavor(payload)
      endeavor_id = payload["endeavor_id"].presence
      return if endeavor_id.nil?

      endeavors = suggestion.minutes_draft_run.meeting_minutes.organization.endeavors
      endeavor = endeavors.find_by(id: endeavor_id)
      return endeavor if endeavor

      suggestion.errors.add(:base, "The proposed Endeavor is no longer available.")
      raise ActiveRecord::RecordInvalid, suggestion
    end

    def append_item_body!(item, text)
      paragraphs = text.to_s.split(/\n{2,}/).map do |paragraph|
        escaped = ERB::Util.html_escape(paragraph).gsub("\n", "<br>")
        "<p>#{escaped}</p>"
      end.join
      combined = [ item.body.to_s.presence, paragraphs ].compact.join
      item.update!(body: ActionText::Content.new(combined))
    end

    def record_review!(state, applied_record = nil)
      suggestion.update!(
        review_state: state,
        reviewed_by: reviewer,
        reviewed_at: Time.current,
        applied_record_type: applied_record&.class&.name,
        applied_record_id: applied_record&.id
      )
    end
  end
end
