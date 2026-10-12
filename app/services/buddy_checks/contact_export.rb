module BuddyChecks
  class ContactExport
    def initialize(access)
      @access = access
    end

    def call(person)
      @access.permission!(person)
      raise Denied, "export_disabled" unless Configuration.export_enabled?
      raise Denied, "export_not_permitted" unless @access.export_enabled?
      directory = Person.directory_visible.exists?(id: person.id)
      # Assignment access permits an outreach card, not an unapproved permanent copy.
      manager = @access.user.full_membership_access?
      raise Denied, "export_not_permitted" unless directory || manager
      review = BuddyAddressReview.where(person:).order(id: :desc).first if manager
      address = review&.current_source? ? review.components : {}
      fields = { first_name: person.first_name, last_name: person.last_name,
        company: ENV["MOBILE_CONTACT_COMPANY"].presence || @access.organization.name,
        phone: person.directory_phone_number, email: person.directory_email_address, address: }
      version = Digest::SHA256.hexdigest(JSON.generate([ person.id, fields, manager, review&.id ]))
      { person_id: person.id, source: "legion_post_tools/person/#{person.id}", version:, fields:,
        permitted_fields: fields.keys.reject { |key| key == :address && !manager },
        address_coverage: address_coverage(manager, address),
        address_review_id: address.present? ? review.id : nil, checked_at: Time.current.iso8601(6) }
    end

    private

    def address_coverage(manager, address)
      return "not_permitted" unless manager
      address.empty? ? "unknown" : "reviewed_components"
    end
  end
end
