require "uri"

module Loops
  class RosterAudience
    Contact = Struct.new(:person, :email, keyword_init: true) do
      def payload
        first_name, last_name = roster_name_parts
        {
          email: email,
          userId: "american-legion-member:#{person.member_number}",
          firstName: first_name,
          lastName: last_name
        }
      end

      private

      def roster_name_parts
        roster_last, roster_first = person.roster_name.to_s.split(",", 2).map(&:strip)
        return [ person.first_name, person.last_name ] unless roster_last.present? && roster_first.present?

        [ roster_first, roster_last ]
      end
    end

    attr_reader :contacts, :missing_email_count, :invalid_email_count, :shared_email_count

    def initialize
      @contacts = []
      @missing_email_count = 0
      @invalid_email_count = 0
      @shared_email_count = 0
      build
    end

    def eligible_count
      contacts.size
    end

    def counts
      {
        eligible_count: eligible_count,
        missing_email_count: missing_email_count,
        invalid_email_count: invalid_email_count,
        shared_email_count: shared_email_count
      }
    end

    private

    def build
      valid_by_email = Hash.new { |hash, email| hash[email] = [] }

      current_members.each do |person|
        email = person.roster_email_address.to_s.strip.downcase
        if email.blank?
          @missing_email_count += 1
        elsif !URI::MailTo::EMAIL_REGEXP.match?(email)
          @invalid_email_count += 1
        else
          valid_by_email[email] << person
        end
      end

      valid_by_email.each do |email, people|
        if people.one?
          @contacts << Contact.new(person: people.first, email: email)
        else
          @shared_email_count += people.size
        end
      end
    end

    def current_members
      Person.roster_backed
        .where(roster_removed_at: nil)
        .where("LOWER(TRIM(COALESCE(roster_member_status, ''))) IN (?)", MembershipReport::CURRENT_STATUSES)
        .order(:last_name, :first_name, :id)
    end
  end
end
