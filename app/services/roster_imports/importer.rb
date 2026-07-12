module RosterImports
  class Importer
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

    def initialize(csv_text:, filename:)
      @csv_text = csv_text
      @filename = filename
    end

    def import
      parsed = CsvParser.new(@csv_text).parse
      if parsed.valid?
        import_rows(parsed.rows, parsed.problems)
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
            disabled = false
            if user && user.disabled_at.blank?
              if user.only_enabled_administrator?
                problems << { row: nil, kind: "last_admin",
                  message: "#{person.roster_display_name} left the roster but is the last administrator — sign-in kept on; review manually." }
              else
                user.update_column(:disabled_at, Time.current)
                disabled = true
              end
            end
            removed_members << { name: person.roster_display_name, member_number: person.member_number, user_disabled: disabled }
          end
        end

        roster_import = RosterImport.create!(
          status: "completed", imported_at: Time.current, uploaded_filename: @filename,
          created_count: created, updated_count: updated, unchanged_count: unchanged,
          removed_count: removed, problem_count: problems.size,
          summary: { rows: rows.size, created: created, updated: updated, unchanged: unchanged,
                     removed: removed, problems: problems, removed_members: removed_members }
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
