module BuddyChecks
  class CoordinationController < ApplicationController
    before_action :require_authentication
    before_action :load_coordination
    before_action :load_person, only: %i[show care record_care preference]
    rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

    def index
      @care_due = BuddyCareUpdate.where(organization: @organization, status: "needs_attention").latest
        .where("follow_up_on <= ?", Organization.current_local_date).count
      @query = params[:q].to_s
      @result = params[:result].presence_in(MembershipContact::OUTCOMES.keys)
      scope = @coordination.contacts
      scope = scope.where(person_id: PeopleSearch.new(Person.roster_backed).call(@query).select(:id)) if @query.present?
      scope = scope.where(outcome: @result) if @result
      @page = params[:page].to_i.clamp(1, 10_000)
      @contacts = scope.recent.includes(:person, recorded_by: :person).limit(26).offset((@page - 1) * 25).to_a
      @more = @contacts.size > 25
      @contacts = @contacts.first(25)
    rescue ArgumentError
      @error = "Enter a member name between 2 and 80 characters."
      @contacts = []
      render :index, status: :unprocessable_entity
    end

    def coverage
      @days = params[:days].present? ? Integer(params[:days]) : 60
      raise ArgumentError unless @days.between?(1, 730)
      @filter = params[:filter].presence_in(%w[attention all no_contact extra_care]) || "attention"
      @rows = @coordination.coverage(days: @days)
      available = @rows.reject { |row| row[:paused] }
      @coverage_summary = { available: available.size, reached: available.count { |row| row[:last_conversation] && row[:last_conversation].occurred_on > Organization.current_local_date - @days },
        attention: @rows.count { |row| row[:needs_check] }, paused: @rows.count { |row| row[:paused] } }
      @rows = case @filter
      when "attention" then @rows.select { |row| row[:needs_check] }
      when "no_contact" then @rows.select { |row| row[:paused] }
      when "extra_care" then @rows.select { |row| row[:extra_care] }
      else @rows
      end
      @query = params[:q].to_s
      if @query.present?
        ids = PeopleSearch.new(Person.roster_backed).call(@query).pluck(:id)
        @rows = @rows.select { |row| ids.include?(row[:person].id) }
      end
      @rows.sort_by! do |row|
        priority = if row[:extra_care]
          0
        elsif row[:missing_meetings]
          1
        else
          2
        end
        [ priority, row[:extra_care]&.follow_up_on || Date.new(2100), row[:person].last_name, row[:person].first_name, row[:person].id ]
      end
      @total = @rows.size
      @page = params[:page].to_i.clamp(1, 10_000)
      @more = @total > @page * 25
      @rows = @rows.slice((@page - 1) * 25, 25) || []
    rescue ArgumentError
      @error = "Choose a look-back between 1 and 730 days and a member name between 2 and 80 characters."
      @rows = []
      render :coverage, status: :unprocessable_entity
    end

    def report
      @month_value = params[:month].presence || Organization.current_local_date.strftime("%Y-%m")
      if params[:year].present? || params[:month_number].present?
        @month_value = "#{params[:year]}-#{params[:month_number].to_s.rjust(2, '0')}"
      end
      raise ArgumentError unless @month_value.match?(/\A(?:20\d\d|2100)-(?:0[1-9]|1[0-2])\z/)
      @month = Date.iso8601("#{@month_value}-01")
      @count = @coordination.month_count(@month)
    rescue ArgumentError
      @error = "Choose a reporting month between 2000 and 2100."
      render :report, status: :unprocessable_entity
    end

    def show
      @contacts = @coordination.contacts.where(person: @person).recent.includes(recorded_by: :person).limit(50)
      @care_updates = BuddyCareUpdate.where(organization: @organization, person: @person).order(revision: :desc).includes(recorded_by: :person, assigned_to: :person)
      @current_care = @care_updates.first
      @paused = Access.new(user: current_user, organization: @organization).paused?(@person)
      @can_prepare = current_user.mobile_buddy_checks_access? && !@paused && Access.new(user: current_user, organization: @organization).people.exists?(id: @person.id)
      @preference_key = SecureRandom.uuid
    end

    def preference
      attributes = params.expect(preference: [ :outcome, :notes, :submission_key ]).to_h.symbolize_keys
      raise ArgumentError unless attributes[:outcome].in?(%w[do_not_contact contact_permission_restored])
      MembershipWorkspace.new(user: current_user, organization: @organization, membership_year: Organization.current_local_date.year)
        .record_contact!(attributes.merge(person_id: @person.id, purpose: "buddy_check", channel: "administrative_review", occurred_on: Organization.current_local_date))
      redirect_to buddy_checks_member_history_path(@person), notice: "Buddy Check contact preference recorded.", status: :see_other
    rescue ActiveRecord::RecordInvalid => error
      @preference_error = error.record.errors.full_messages.to_sentence
      @preference_values = attributes
      show
      render :show, status: :unprocessable_entity
    rescue ArgumentError, ActionController::ParameterMissing
      head :unprocessable_entity
    rescue MembershipWorkspace::AccessDenied
      head :forbidden
    end

    def care
      load_care_form
      @form = { submission_key: SecureRandom.uuid, expected_revision: @current_care&.revision || 0,
        status: "needs_attention", assigned_to_id: @current_care&.assigned_to_id || current_user.id,
        follow_up_on: @current_care&.follow_up_on || Organization.current_local_date }.with_indifferent_access
    end

    def record_care
      @form = params.expect(care: [ :submission_key, :expected_revision, :status, :assigned_to_id, :follow_up_on, :notes ]).to_h
      BuddyCareUpdate.record!(user: current_user, organization: @organization, person: @person,
        expected_revision: @form["expected_revision"], attributes: @form.except("expected_revision"))
      redirect_to buddy_checks_member_history_path(@person), notice: "Care follow-up recorded. Earlier reviews are preserved.", status: :see_other
    rescue ActiveRecord::RecordInvalid => error
      @error = error.record.errors.full_messages.to_sentence
      load_care_form
      render :care, status: :unprocessable_entity
    rescue BuddyChecks::Conflict
      @error = "This care review changed while the form was open. Reload and review the current record before saving."
      load_care_form
      render :care, status: :conflict
    rescue BuddyChecks::Denied
      head :forbidden
    rescue ArgumentError, ActionController::ParameterMissing
      head :unprocessable_entity
    end

    private

    def load_coordination
      response.cache_control.replace(no_store: true)
      unless current_user.buddy_check_coordination_access?
        @error = "Post-wide Buddy Check activity and care reviews are available to authorized Post coordinators."
        return render "buddy_checks/coordination/denied", status: :forbidden
      end
      @organization = Organization.first!
      @coordination = Coordination.new(organization: @organization)
    end

    def load_person
      @person = Person.roster_backed.find(params[:id])
    end

    def load_care_form
      @current_care = BuddyCareUpdate.where(organization: @organization, person: @person).order(revision: :desc).first
      @owners = User.where(disabled_at: nil).includes(:person).order(:email_address).select(&:buddy_check_coordination_access?)
    end
  end
end
