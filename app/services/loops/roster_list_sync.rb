module Loops
  # Owns one list key. Never copies another workflow's subscriptions into an update.
  class RosterListSync
    attr_reader :results, :review_failures

    def initialize(organization, settings, client)
      @organization, @settings, @client = organization, settings, client
      @results = Hash.new(0)
      @review_failures = []
    end

    def sync(contact)
      payload = contact.payload
      by_email = @client.find_contact(email: contact.email)
      by_user = @client.find_contact(user_id: payload.fetch(:userId))
      if (by_user && by_user["email"].to_s.downcase != contact.email) ||
          (by_email && by_email["userId"].present? && by_email["userId"] != payload.fetch(:userId)) ||
          (by_user && by_email && by_user["id"] != by_email["id"])
        @results["identity_conflicts"] += 1
        raise Client::RequestError, "Email and National member identity conflict. Review the contact and its other subscriptions in Loops."
      end
      existing = by_email || by_user
      was_member = existing&.fetch("mailingLists", {})&.fetch(@settings.post_members_list_id, false) == true
      @client.update_contact(payload.merge(mailingLists: { @settings.post_members_list_id => true }))
      saved = @client.find_contact(email: contact.email)
      raise Client::RequestError, "Loops did not return the updated contact." unless saved

      enrolled = saved.fetch("mailingLists", {})[@settings.post_members_list_id] == true
      result = if !enrolled || saved["subscribed"] != true
        "retained_opt_outs"
      elsif was_member
        "unchanged"
      else
        "added"
      end
      @results[result] += 1
      record = @organization.loops_roster_enrollments.find_or_initialize_by(email: contact.email, list_id: @settings.post_members_list_id)
      # Do not claim ownership of a pre-existing list assignment without provenance.
      if record.persisted? || !was_member
        record.update!(member_user_id: payload.fetch(:userId), loops_contact_id: saved.fetch("id"), active: enrolled)
      end
    end

    def reconcile(audience)
      emails = audience.contacts.map(&:email)
      current_user_ids = audience.contacts.map { |contact| contact.payload.fetch(:userId) }
      @organization.loops_roster_enrollments.where(list_id: @settings.post_members_list_id, active: true).where.not(email: emails).find_each do |record|
        reconcile_record(record, current_user_ids)
      rescue Client::RequestError => error
        review_removal(record, error.message)
      end
    end

    private

    def reconcile_record(record, current_user_ids)
      if current_user_ids.include?(record.member_user_id)
        return review_removal(record, "This member changed address. Review the existing contact and its independent subscriptions.")
      end
      contact = @client.find_contact(email: record.email)
      unless contact && contact["id"] == record.loops_contact_id && contact["userId"] == record.member_user_id
        return review_removal(record, "The saved contact identity changed or is missing. Review it before removal.")
      end
      @client.update_contact(email: record.email, mailingLists: { @settings.post_members_list_id => false })
      saved = @client.find_contact(email: record.email)
      if saved && saved.fetch("mailingLists", {})[@settings.post_members_list_id] != true
        record.update!(active: false)
        @results["removed"] += 1
      else
        review_removal(record, "Loops did not confirm removal from Post members. Review this contact.")
      end
    end

    def review_removal(record, message)
      @results["removal_needs_review"] += 1
      @review_failures << { "name" => "Previously managed contact", "member_number" => record.member_user_id.delete_prefix("american-legion-member:"),
        "email" => record.email, "message" => message, "status" => nil }
    end
  end
end
