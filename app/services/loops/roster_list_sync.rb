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
      if (by_user && by_user["userId"] != payload.fetch(:userId)) ||
          (by_email && by_email["userId"].present? && by_email["userId"] != payload.fetch(:userId)) ||
          (by_user && by_email && by_user["id"] != by_email["id"])
        @results["identity_conflicts"] += 1
        raise Client::RequestError, "Email and National member identity conflict. Review the contact and its other subscriptions in Loops."
      end
      existing = by_email || by_user
      address_changed = existing && existing["email"].to_s.downcase != contact.email
      if address_changed && ![ true, false ].include?(existing["subscribed"])
        raise Client::RequestError, "Loops subscription choices are unreadable. Review the contact before changing its email."
      end
      was_member = existing&.fetch("mailingLists", {})&.fetch(@settings.post_members_list_id, false) == true
      # Moving the same contact must not change any of its subscription choices.
      update = address_changed ? payload : payload.merge(mailingLists: { @settings.post_members_list_id => true })
      @client.update_contact(update)
      saved = @client.find_contact(email: contact.email)
      unless saved && saved["email"].to_s.downcase == contact.email && saved["userId"] == payload.fetch(:userId) &&
          (!existing || saved["id"] == existing["id"])
        raise Client::RequestError, "Loops did not confirm the updated contact identity. Review it before syncing again."
      end
      if address_changed && (saved["subscribed"] != existing["subscribed"] || saved["mailingLists"] != existing["mailingLists"])
        raise Client::RequestError, "Loops did not preserve the contact's subscription choices during its email change. Review it in Loops."
      end

      enrolled = saved.fetch("mailingLists", {})[@settings.post_members_list_id] == true
      result = if !enrolled || saved["subscribed"] != true
        "retained_opt_outs"
      elsif was_member
        "unchanged"
      else
        "added"
      end
      @results[result] += 1
      record_enrollment(contact, payload, saved, enrolled, was_member)
      @results["email_addresses_updated"] += 1 if address_changed
    end

    def reconcile(audience)
      RosterAudience.departed_members.find_each do |person|
        unsubscribe_departed_member(person)
      rescue Client::RequestError => error
        @results["removal_needs_review"] += 1
        @review_failures << { "name" => person.roster_display_name, "member_number" => person.member_number,
          "email" => person.roster_email_address, "message" => error.message, "status" => error.status }
      end
      emails = audience.contacts.map(&:email)
      current_user_ids = audience.contacts.map { |contact| contact.payload.fetch(:userId) }
      @organization.loops_roster_enrollments.where(list_id: @settings.post_members_list_id, active: true).where.not(email: emails).find_each do |record|
        reconcile_record(record, current_user_ids)
      rescue Client::RequestError => error
        review_removal(record, error.message)
      end
    end

    private

    def unsubscribe_departed_member(person)
      user_id = "american-legion-member:#{person.member_number}"
      contact = @client.find_contact(user_id: user_id)
      if !contact && person.roster_email_address.present?
        contact = @client.find_contact(email: person.roster_email_address)
      end
      return unless contact

      email = contact.fetch("email").downcase
      if (contact["userId"].present? && contact["userId"] != user_id) ||
          Person.roster_backed.where.not(id: person.id).exists?(roster_email_address: email)
        raise Client::RequestError, "Another roster member uses this contact identity or email. Review before unsubscribing it."
      end

      was_member = contact.fetch("mailingLists", {})[@settings.post_members_list_id] == true
      if contact["subscribed"] != false || was_member
        @client.update_contact(email: email, userId: user_id, subscribed: false,
          mailingLists: { @settings.post_members_list_id => false })
        saved = @client.find_contact(email: email)
        unless saved && saved["id"] == contact["id"] && saved["userId"] == user_id && saved["subscribed"] == false &&
            saved.fetch("mailingLists", {})[@settings.post_members_list_id] != true
          raise Client::RequestError, "Loops did not confirm global unsubscription. Review this departed or deceased member."
        end
        @results["globally_unsubscribed"] += 1 if contact["subscribed"] != false
        @results["removed"] += 1 if was_member
      end
      @organization.loops_roster_enrollments.where(member_user_id: user_id, loops_contact_id: contact.fetch("id"), active: true)
        .update_all(active: false, updated_at: Time.current)
    end

    def record_enrollment(contact, payload, saved, enrolled, was_member)
      records = @organization.loops_roster_enrollments.where(list_id: @settings.post_members_list_id)
      managed = records.where(member_user_id: payload.fetch(:userId), loops_contact_id: saved.fetch("id"))
      record = records.find_or_initialize_by(email: contact.email)
      # Existing provenance also recovers a move accepted by Loops before a local interruption.
      # Do not claim ownership of a pre-existing list assignment without provenance.
      if record.persisted? || !was_member || managed.exists?
        LoopsRosterEnrollment.transaction do
          record.update!(member_user_id: payload.fetch(:userId), loops_contact_id: saved.fetch("id"), active: enrolled)
          managed.where.not(email: contact.email).where(active: true).update_all(active: false, updated_at: Time.current)
        end
      end
    end

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
