module MinutesEndeavors
  class Confirm
    def self.call(item:, reviewer:, attributes:, suggestion: nil)
      new(item:, reviewer:, attributes:, suggestion:).call
    end

    def initialize(item:, reviewer:, attributes:, suggestion:)
      @item = item
      @reviewer = reviewer
      @attributes = attributes.to_h.stringify_keys
      @suggestion = suggestion
    end

    def call
      invalid!("You need permission to manage minutes to link an Endeavor.") unless reviewer.can?("manage_minutes")
      invalid!("Choose whether to create or link an Endeavor.") unless mode.in?(%w[create link])
      if mode == "create" && !reviewer.can?("manage_agendas")
        invalid!("You need permission to manage agendas to create an Endeavor.")
      end
      invalid!("Choose an existing Endeavor.") if mode == "link" && attributes["endeavor_id"].blank?

      minutes.with_lock do
        invalid!("Reopen these minutes before linking an Endeavor.") unless minutes.draft?
        item.lock!
        check_version!
        if mode == "create" && item.endeavor_id.present?
          invalid!("This item already has a confirmed Endeavor. Review its current link.")
        end
        if suggestion
          suggestion.lock!
          invalid!("That proposal has already been reviewed.") unless suggestion.unreviewed?
          unless suggestion.kind == "endeavor_proposal" && suggestion.minutes_item_id == item.id && suggestion.minutes_draft_run.meeting_minutes_id == minutes.id
            invalid!("The proposal must belong to this minutes item.")
          end
          invalid!("This item already has a confirmed Endeavor. Review its current link.") if item.endeavor_id.present?
        end

        endeavor = mode == "create" ? create_endeavor! : minutes.organization.endeavors.find(attributes.fetch("endeavor_id"))
        item.update!(endeavor: endeavor)
        record_review!(endeavor) if suggestion
        endeavor
      end
    end

    private

    attr_reader :item, :reviewer, :attributes, :suggestion

    def minutes = item.meeting_minutes
    def mode = attributes["endeavor_action"]

    def check_version!
      invalid!("Review the current minutes item before confirming.") if attributes["lock_version"].blank?
      version = Integer(attributes.fetch("lock_version").to_s, 10)
      raise ActiveRecord::StaleObjectError.new(item, "link") unless version == item.lock_version
    rescue ArgumentError
      invalid!("Review the current minutes item before confirming.")
    end

    def create_endeavor!
      organization = minutes.organization
      organization.with_lock do
        title = attributes["title"].to_s.strip
        if title.present? && organization.endeavors.any? { |record| record.title.squish.downcase == title.squish.downcase }
          invalid!("An Endeavor with this title already exists. Choose Link existing instead.")
        end
        organization.endeavors.create!(
          title: title,
          summary: attributes["body"].to_s.strip,
          importance: "standard",
          status: "active",
          created_by: reviewer
        )
      end
    end

    def record_review!(endeavor)
      unchanged = if mode == "create"
        endeavor.title == suggestion.payload["title"] && endeavor.summary == suggestion.payload["body"]
      else
        endeavor.id == suggestion.payload["endeavor_id"]
      end
      suggestion.update!(
        review_state: unchanged ? "used" : "edited",
        reviewed_by: reviewer,
        reviewed_at: Time.current,
        applied_record_type: "Endeavor",
        applied_record_id: endeavor.id
      )
    end

    def invalid!(message)
      item.errors.add(:base, message)
      raise ActiveRecord::RecordInvalid, item
    end
  end
end
