module Api
  module Concerns
    module ActivityContract
      extend ActiveSupport::Concern

      included do
        rescue_from ArgumentError do |error|
          render_error(error.message, status: :unprocessable_entity, details: [ error.message ])
        end
        rescue_from ActiveRecord::RecordInvalid do |error|
          render_validation_error(error.record, fallback: "Check the activity fields.")
        end
        rescue_from ActiveRecord::StaleObjectError do
          render_error("This record changed. Fetch it again before editing.", status: :conflict)
        end
      end

      private

      def calendar_filter_categories
        return nil unless params.key?(:categories)

        values = params[:categories]
        unless values.is_a?(Array) && (values - CalendarCategories::LABELS.keys - [ "" ]).empty?
          raise ArgumentError, "categories must be an array of calendar category values."
        end
        values.reject(&:blank?)
      end

      def activity_date(value, field:)
        return nil if value.nil? || value == ""
        raise ArgumentError, "#{field} must be a YYYY-MM-DD date." unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/)

        Date.iso8601(value)
      rescue Date::Error
        raise ArgumentError, "#{field} must be a valid YYYY-MM-DD date."
      end

      def activity_boolean(field)
        value = params[field]
        raise ArgumentError, "#{field} must be true or false." unless value == true || value == false

        value
      end

      def activity_lock_version!(record)
        value = params[:lock_version]
        raise ArgumentError, "lock_version must be the last-read nonnegative integer." unless value.is_a?(Integer) && value >= 0

        raise ActiveRecord::StaleObjectError.new(record, "update") if value != record.lock_version

        value
      end

      def activity_preview?
        return false unless params.key?(:preview)
        raise ArgumentError, "preview must be public." unless params[:preview] == "public"

        true
      end

      def calendar_event_payload(event, public_preview: false)
        return event.public_calendar_attributes if public_preview

        event.attributes.slice("id", "title", "description", "location", "starts_at", "ends_at", "all_day", "cancelled", "visibility", "endeavor_id", "lock_version", "created_by_id", "updated_by_id", "created_at", "updated_at", "calendar_category").merge("category" => CalendarCategories.for(event))
      end

      def endeavor_task_payload(task)
        task.attributes.slice("id", "endeavor_id", "title", "due_on", "completed_at", "completed_by_id", "created_by_id", "updated_by_id", "lock_version", "created_at", "updated_at").merge("completed" => task.completed?)
      end
    end
  end
end
