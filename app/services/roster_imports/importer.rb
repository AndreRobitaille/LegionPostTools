require "uri"

module RosterImports
  class Importer
    LARGE_REMOVAL_THRESHOLD = 10
    CREATED_MEMBER_EXAMPLE_LIMIT = 10
    ROSTER_ATTRIBUTES = {
      roster_name: :name,
      roster_post: :post,
      roster_membership_type: :membership_type,
      roster_address: :address,
      roster_undeliverable: :undeliverable,
      roster_email_address: :email_address,
      roster_phone_number: :phone_number,
      roster_branch: :branch,
      roster_war_era: :war_era,
      roster_continuous_years: :continuous_years,
      roster_paid_through_year: :paid_through_year,
      roster_member_status: :member_status
    }.freeze
    NUMERIC_DELTA_ATTRIBUTES = %i[roster_continuous_years].freeze
    SAFE_TRANSITION_ATTRIBUTES = %i[
      roster_membership_type
      roster_war_era
      roster_paid_through_year
      roster_member_status
    ].freeze

    Result = Struct.new(
      :roster_import,
      :errors,
      :created_count,
      :updated_count,
      :unchanged_count,
      :removed_count,
      :problem_count,
      keyword_init: true
    ) do
      def success?
        errors.empty? && roster_import&.status == "completed"
      end
    end

    def initialize(csv_text:, filename:, roster_import: nil, confirm_large_removal: false)
      @csv_text = csv_text
      @filename = filename
      @roster_import = roster_import
      @confirm_large_removal = confirm_large_removal
    end

    def import
      parsed = CsvParser.new(@csv_text).parse
      if parsed.valid?
        if !@confirm_large_removal && large_removal_confirmation_required?(parsed.rows)
          pending_import(parsed.rows, parsed.problems)
        else
          import_rows(parsed.rows, parsed.problems)
        end
      else
        failed_import(parsed.fatal_errors)
      end
    end

    private

    def import_rows(rows, row_problems)
      created = updated = unchanged = removed = returned = 0
      imported_member_numbers = []
      problems = row_problems.map { |p| { row: p.row, kind: p.kind, message: p.message } }
      removed_members = []
      created_members = []
      field_changes = {}
      access_effects = Hash.new(0)
      email_counts = eligible_email_counts(rows)
      roster_import = nil

      ActiveRecord::Base.transaction do
        rows.each do |row|
          person = Person.find_or_initialize_by(member_number: row.member_number)
          was_new = person.new_record?
          was_returning = !was_new && person.roster_removed_at.present?
          changes = was_new ? {} : roster_field_changes(person, row)
          assign_roster_fields(person, row)
          split_name(person, row.name) if was_new
          person.roster_removed_at = nil if was_returning

          if person.changed?
            person.roster_imported_at = Time.current
            person.save!
            if was_new
              created += 1
              if created_members.size < CREATED_MEMBER_EXAMPLE_LIMIT
                created_members << { name: person.roster_display_name, member_number: person.member_number }
              end
            else
              updated += 1
              returned += 1 if was_returning
              record_field_changes(field_changes, changes)
            end
          else
            person.update_column(:roster_imported_at, Time.current) if person.persisted?
            unchanged += 1
          end

          effect = reconcile_login_access(person, email_counts, problems)
          if effect
            access_effects[effect.to_s] += 1
            if effect == :skipped_last_admin
              problems << { row: nil, kind: "last_admin",
                message: "#{person.roster_display_name} would lose sign-in by roster status but is the last administrator — sign-in kept on; review manually." }
            end
          end
          imported_member_numbers << row.member_number
        end

        if imported_member_numbers.any?
          Person.where(roster_removed_at: nil)
                .where.not(roster_imported_at: nil)
                .where.not(member_number: imported_member_numbers)
                .includes(:user).find_each do |person|
            person.update_column(:roster_removed_at, Time.current)
            removed += 1
            user = person.user
            effect = nil
            was_enabled = user&.disabled_at.blank?
            if user
              effect = user.apply_roster_access!
              access_effects[effect.to_s] += 1
              if effect == :skipped_last_admin
                problems << { row: nil, kind: "last_admin",
                  message: "#{person.roster_display_name} left the roster but is the last administrator — sign-in kept on; review manually." }
              end
            end
            removed_members << {
              name: person.roster_display_name,
              member_number: person.member_number,
              user_disabled: was_enabled && effect == :disabled_by_roster_status
            }
          end
        end

        roster_import = @roster_import || RosterImport.new
        roster_import.update!(
          status: "completed", imported_at: Time.current, uploaded_filename: @filename,
          created_count: created, updated_count: updated, unchanged_count: unchanged,
          removed_count: removed, problem_count: problems.size,
          summary: { rows: rows.size, created: created, updated: updated, unchanged: unchanged,
                     removed: removed, problems: problems, removed_members: removed_members,
                     access_effects: access_effects, field_changes: field_changes,
                     returned_count: returned, created_members: created_members }
        )
      end

      Result.new(roster_import: roster_import, errors: [], created_count: created, updated_count: updated,
                 unchanged_count: unchanged, removed_count: removed, problem_count: problems.size)
    rescue ActiveRecord::RecordInvalid => e
      failed_import([ e.message ])
    end

    def failed_import(errors)
      roster_import = RosterImport.create!(
        status: "failed", imported_at: Time.current, uploaded_filename: @filename,
        created_count: 0, updated_count: 0, unchanged_count: 0, removed_count: 0, problem_count: errors.size,
        summary: { problems: errors.map { |message| { row: nil, kind: "fatal", message: message } } }
      )
      Result.new(roster_import: roster_import, errors: errors, created_count: 0, updated_count: 0,
                 unchanged_count: 0, removed_count: 0, problem_count: errors.size)
    end

    def large_removal_confirmation_required?(rows)
      rows.any? && pending_removed_people(rows).size > LARGE_REMOVAL_THRESHOLD
    end

    def pending_removed_people(rows)
      imported_member_numbers = rows.map(&:member_number)
      Person.where(roster_removed_at: nil)
            .where.not(roster_imported_at: nil)
            .where.not(member_number: imported_member_numbers)
            .includes(:user)
            .to_a
    end

    def pending_import(rows, row_problems)
      removed_people = pending_removed_people(rows)
      reserved_admin_id = pending_removed_admin_reservation_id(removed_people)
      removed_members = removed_people.map do |person|
        user = person.user
        would_disable_sign_in = user.present? && user.disabled_at.blank?
        would_disable_sign_in &&= !user.can?("manage_settings") || person.user.id != reserved_admin_id

        {
          name: person.roster_display_name,
          member_number: person.member_number,
          would_disable_sign_in: would_disable_sign_in
        }
      end
      sign_in_disable_count = removed_members.count { |member| member[:would_disable_sign_in] }
      problems = row_problems.map { |p| { row: p.row, kind: p.kind, message: p.message } }
      roster_import = RosterImport.new(
        status: "pending_confirmation",
        imported_at: Time.current,
        uploaded_filename: @filename,
        removed_count: removed_people.size,
        problem_count: problems.size,
        summary: {
          rows: rows.size,
          problems: problems,
          removed_members: removed_members,
          removal_confirmation: {
            removed_count: removed_people.size,
            sign_in_disable_count: sign_in_disable_count
          }
        }
      )
      roster_import.pending_csv.attach(io: StringIO.new(@csv_text), filename: @filename, content_type: "text/csv")
      roster_import.save!
      Result.new(roster_import: roster_import, errors: [ "confirmation_required" ], created_count: 0,
                  updated_count: 0, unchanged_count: 0, removed_count: removed_people.size, problem_count: problems.size)
    end

    def pending_removed_admin_reservation_id(removed_people)
      removed_admins = removed_people.filter_map do |person|
        user = person.user
        next unless user && user.disabled_at.blank? && user.can?("manage_settings")

        user
      end

      return nil if removed_admins.empty?

      outside_enabled_admin_exists = User.where(disabled_at: nil)
        .joins(:permission_grants)
        .where(permission_grants: { capability: "manage_settings" })
        .where.not(id: removed_admins.map(&:id))
        .exists?

      return nil if outside_enabled_admin_exists

      removed_admins.min_by(&:id).id
    end

    def reconcile_login_access(person, email_counts, problems)
      if person.user
        unsupported_status = person.user.roster_access_unsupported_status?
        effect = person.user.apply_roster_access!
        if unsupported_status && effect != :skipped_last_admin
          outcome = effect == :skipped_manual_disable ? "sign-in remains off by administrator" : "sign-in was turned off"
          problems << {
            row: nil,
            kind: "unsupported_member_status",
            message: "#{person.roster_display_name} has unsupported member status #{person.roster_member_status.inspect}; #{outcome}."
          }
        end
        return effect
      end

      status = person.normalized_roster_status
      unless User::ROSTER_LOGIN_ENABLED_STATUSES.include?(status)
        return if User::ROSTER_LOGIN_DISABLED_STATUSES.include?(status)

        problems << {
          row: nil,
          kind: "unsupported_member_status",
          message: "#{person.roster_display_name} has unsupported member status #{person.roster_member_status.inspect}; no sign-in account was created."
        }
        return :unsupported_status_without_account
      end

      email = person.roster_email_address.to_s.strip.downcase
      problem = login_email_problem(person, email, email_counts)
      if problem
        problems << problem
        return problem.fetch(:kind).to_sym
      end

      User.create!(person: person, email_address: email)
      :account_created
    end

    def login_email_problem(person, email, email_counts)
      kind, explanation = if email.blank?
        [ "account_not_created_missing_email", "has no roster email" ]
      elsif !URI::MailTo::EMAIL_REGEXP.match?(email)
        [ "account_not_created_invalid_email", "has an invalid roster email" ]
      elsif email_counts.fetch(email, 0) > 1
        [ "account_not_created_shared_email", "shares a roster email with another current member" ]
      elsif User.exists?(email_address: email)
        [ "account_not_created_email_in_use", "has a roster email already used by another login account" ]
      end

      return unless kind

      {
        row: nil,
        kind: kind,
        message: "#{person.roster_display_name} is a current member but #{explanation}; no sign-in account was created."
      }
    end

    def eligible_email_counts(rows)
      rows.filter_map do |row|
        next unless User::ROSTER_LOGIN_ENABLED_STATUSES.include?(row.member_status.to_s.strip.downcase)

        row.email_address.to_s.strip.downcase.presence
      end.tally
    end

    def assign_roster_fields(person, row)
      person.assign_attributes(roster_attributes(row))
    end

    def roster_attributes(row)
      ROSTER_ATTRIBUTES.to_h { |attribute, row_attribute| [ attribute, row.public_send(row_attribute) ] }
    end

    def roster_field_changes(person, row)
      roster_attributes(row).filter_map do |attribute, new_value|
        old_value = person.public_send(attribute)
        [ attribute, [ old_value, new_value ] ] unless old_value == new_value
      end.to_h
    end

    def record_field_changes(field_changes, changes)
      changes.each do |attribute, (old_value, new_value)|
        change = field_changes[attribute.to_s] ||= { "count" => 0 }
        change["count"] += 1

        if NUMERIC_DELTA_ATTRIBUTES.include?(attribute) && old_value.present? && new_value.present?
          record_numeric_delta(change, old_value, new_value)
        elsif SAFE_TRANSITION_ATTRIBUTES.include?(attribute)
          record_transition(change, old_value, new_value)
        end
      end
    end

    def record_numeric_delta(change, old_value, new_value)
      delta = (new_value - old_value).to_s
      deltas = change["deltas"] ||= {}
      deltas[delta] = deltas.fetch(delta, 0) + 1
    end

    def record_transition(change, old_value, new_value)
      transitions = change["transitions"] ||= []
      from = old_value.presence&.to_s || "blank"
      to = new_value.presence&.to_s || "blank"
      transition = transitions.find { |entry| entry["from"] == from && entry["to"] == to }

      if transition
        transition["count"] += 1
      else
        transitions << { "from" => from, "to" => to, "count" => 1 }
      end
    end

    def split_name(person, name)
      last, first = name.to_s.split(",", 2).map { |part| part&.strip }
      if first.present? && last.present?
        person.first_name = first
        person.last_name = last
      else
        person.first_name = name.to_s.strip.presence || "Unknown"
        person.last_name = "Member"
      end
    end
  end
end
