require "csv"

module RosterImports
  class CsvParser
    REQUIRED_HEADERS = [
      "Member ID",
      "Name",
      "Post/Squadron Number",
      "Type",
      "Address",
      "Undeliverable",
      "Email",
      "PhoneNumber",
      "Branch",
      "Conflict/War Era",
      "Continuous Years",
      "Paid Through Year",
      "Member Status"
    ].freeze

    Row = Struct.new(
      :member_number,
      :name,
      :post,
      :membership_type,
      :address,
      :undeliverable,
      :email_address,
      :phone_number,
      :branch,
      :war_era,
      :continuous_years,
      :paid_through_year,
      :member_status,
      keyword_init: true
    )

    Result = Struct.new(:rows, :errors, keyword_init: true) do
      def valid?
        errors.empty?
      end
    end

    def initialize(csv_text)
      @csv_text = csv_text
    end

    def parse
      csv = CSV.parse(strip_utf8_bom(normalize_utf8(@csv_text)), headers: true)
      validate_headers!(csv.headers)

      rows = []
      errors = []
      seen_member_numbers = {}

      csv.each_with_index do |row, index|
        row_number = index + 2
        member_number = row["Member ID"]&.strip

        if member_number.blank?
          errors << "Row #{row_number} is missing Member ID"
          next
        end

        if seen_member_numbers[member_number]
          errors << "Duplicate Member ID #{member_number} in uploaded roster"
          next
        end

        seen_member_numbers[member_number] = true

        rows << Row.new(
          member_number: member_number,
          name: row["Name"]&.strip,
          post: row["Post/Squadron Number"]&.strip,
          membership_type: row["Type"]&.strip,
          address: row["Address"]&.strip,
          undeliverable: row["Undeliverable"].to_s.strip.casecmp?("Y"),
          email_address: normalize_email(row["Email"]),
          phone_number: row["PhoneNumber"]&.strip,
          branch: row["Branch"]&.strip,
          war_era: row["Conflict/War Era"]&.strip,
          continuous_years: integer_or_nil(row["Continuous Years"]),
          paid_through_year: integer_or_nil(row["Paid Through Year"]),
          member_status: row["Member Status"]&.strip
        )
      end

      Result.new(rows: rows, errors: errors)
    rescue ArgumentError => e
      Result.new(rows: [], errors: [ e.message ])
    rescue CSV::MalformedCSVError => e
      Result.new(rows: [], errors: [ e.message ])
    rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError => e
      Result.new(rows: [], errors: [ e.message ])
    end

    private

    def validate_headers!(headers)
      missing_headers = REQUIRED_HEADERS.reject { |header| headers.include?(header) }
      return if missing_headers.empty?

      raise ArgumentError, "Missing required columns: #{missing_headers.join(", ")}"
    end

    def normalize_email(value)
      value&.strip&.downcase.presence
    end

    def strip_utf8_bom(text)
      text.sub(/\A\uFEFF/, "")
    end

    def normalize_utf8(text)
      text.to_s.dup.force_encoding(Encoding::UTF_8)
    end

    def integer_or_nil(value)
      stripped = value&.strip
      return nil if stripped.blank?

      Integer(stripped)
    rescue ArgumentError
      nil
    end
  end
end
