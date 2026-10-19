module MinutesDistribution::Enrollment
  module_function

  # This is explicit officer enrollment, never a side effect of roster sync or a name edit.
  def call(recipient, client: Loops::Client.new)
    settings = recipient.organization.minutes_distribution_setting
    unless settings&.audiences_reviewed? && recipient.active?
      raise Loops::Client::RequestError, "Review general campaign targeting and activate this entry before enrollment."
    end
    client.open do |session|
      MinutesDistribution::Groups.verify!(settings, session)
      contact = session.find_contact(email: recipient.email)
      if recipient.loops_contact_id && contact&.fetch("id") != recipient.loops_contact_id
        raise Loops::Client::RequestError, "The saved Loops contact changed. Review its identity before enrollment."
      end
      session.update_contact(email: recipient.email, mailingLists: { settings.minutes_recipients_list_id => true })
      contact = session.find_contact(email: recipient.email)
      raise Loops::Client::RequestError, "Loops did not return the enrolled contact." unless contact

      subscribed = contact["subscribed"] == true && contact.fetch("mailingLists", {})[settings.minutes_recipients_list_id] == true
      recipient.update!(loops_contact_id: contact.fetch("id"), enrolled_list_id: settings.minutes_recipients_list_id,
        enrollment_status: subscribed ? "enrolled" : "opted_out")
    end
  end
end
