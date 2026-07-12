module RosterImports
  class Importer
    LARGE_REMOVAL_THRESHOLD = 10

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
      created = updated = unchanged = removed = 0
      imported_member_numbers = []
      problems = row_problems.map { |p| { row: p.row, kind: p.kind, message: p.message } }
      removed_members = []
      access_effects = Hash.new(0)
      roster_import = nil

      ActiveRecord::Base.transaction do
        rows.each do |row|
          person = Person.find_or_initialize_by(member_number: row.member_number)
          was_new = person.new_record?
          assign_roster_fields(person, row)
          split_name(person, row.name) if was_new
          person.roster_removed_at = nil if person.roster_removed_at.present?

          if person.changed?
            person.roster_imported_at = Time.current
            person.save!
            was_new ? created += 1 : updated += 1
          else
            person.update_column(:roster_imported_at, Time.current) if person.persisted?
            unchanged += 1
          end

          if person.user
            effect = person.user.apply_roster_access!
            access_effects[effect.to_s] += 1
            if effect == :unsupported_status
              problems << { row: nil, kind: "unsupported_member_status",
                message: "#{person.roster_display_name} has unsupported member status #{person.roster_member_status.inspect}; sign-in was not changed." }
            elsif effect == :skipped_last_admin
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
                     access_effects: access_effects }
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
        would_disable_sign_in = user.present? && !user.login_access_override? && user.disabled_at.blank?
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
        next unless user && !user.login_access_override? && user.disabled_at.blank? && user.can?("manage_settings")

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

    def assign_roster_fields(person, row)
      person.roster_name = row.name
      person.roster_post = row.post
      person.roster_membership_type = row.membership_type
      person.roster_address = row.address
      person.roster_undeliverable = row.undeliverable
      person.roster_email_address = row.email_address
      person.roster_phone_number = row.phone_number
      person.roster_branch = row.branch
      person.roster_war_era = row.war_era
      person.roster_continuous_years = row.continuous_years
      person.roster_paid_through_year = row.paid_through_year
      person.roster_member_status = row.member_status
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
