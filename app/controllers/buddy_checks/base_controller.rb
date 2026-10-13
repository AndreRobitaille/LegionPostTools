module BuddyChecks
  class BaseController < ApplicationController
    before_action :require_authentication
    before_action :load_buddy_workspace

    rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }
    rescue_from BuddyChecks::Denied, with: :contact_denied
    rescue_from ArgumentError, ActionController::ParameterMissing, with: :invalid_request

    private

    def load_buddy_workspace
      response.headers["Cache-Control"] = "no-store"
      return head :forbidden unless current_user.mobile_buddy_checks_access?

      @organization = Organization.first!
      @access = BuddyChecks::Access.new(user: current_user, organization: @organization)
      @operations = BuddyChecks::Operations.new(@access)
    end

    def suggestions
      @suggestions ||= BuddyChecks::Suggestions.new(@access)
    end

    def local_instant(value)
      raise ArgumentError, "Choose a date and time." unless value.to_s.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}\z/)
      Date.iso8601(value.split("T").first)
      @organization.calendar_time_zone.strptime(value, "%Y-%m-%dT%H:%M").iso8601
    end

    def local_now
      Time.current.in_time_zone(@organization.calendar_time_zone).strftime("%Y-%m-%dT%H:%M")
    end

    def entry_zone
      @organization.calendar_time_zone.tzinfo.identifier
    end

    def form_error(error)
      case error
      when BuddyChecks::Conflict, ActiveRecord::StaleObjectError
        "This work changed while the page was open. Reload it and review the current record before saving again."
      when ActiveRecord::RecordInvalid
        error.record.errors.full_messages.to_sentence
      else
        case error.message
        when "invalid_channel", "invalid_outcome"
          "Choose the actual phone, text, or in-person contact and its result. Other earlier contact types need a Buddy Check coordinator's review."
        else
          "Check the date, time, and result. Checks must describe an actual past contact; callbacks and deferrals need a future date and time."
        end
      end
    end

    def contact_denied
      render "buddy_checks/denied", status: :forbidden
    end

    def invalid_request(error)
      @error = form_error(error)
      render "buddy_checks/denied", status: :unprocessable_entity
    end
  end
end
