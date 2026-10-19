# An offline Loops boundary with sparse list writes, opt-outs and idempotent sends.
class MinutesDistributionProvider
  attr_reader :contacts, :payloads, :messages, :attempts, :suppressed, :list_opt_outs, :open_count
  attr_accessor :lists, :rejected_email, :terminal_error, :timeout_after_accept, :before_send

  def initialize
    @contacts, @payloads, @messages, @attempts = {}, [], [], []
    @suppressed, @list_opt_outs = [], []
    @keys = {}
    @open_count = 0
    @lists = [ { "id" => "members", "isPublic" => false }, { "id" => "minutes", "isPublic" => false } ]
  end

  def open
    @open_count += 1
    raise terminal_error if terminal_error
    yield self
  end

  def mailing_lists = lists

  def find_contact(email: nil, user_id: nil)
    contact = email ? contacts[email] : contacts.values.find { |entry| entry["userId"] == user_id }
    contact&.deep_dup
  end

  def suppressed?(email:) = suppressed.include?(email)

  def add(email, **attributes)
    contacts[email] = { "id" => "contact-#{contacts.size + 1}", "email" => email,
      "subscribed" => true, "mailingLists" => {} }.merge(attributes.stringify_keys)
  end

  def update_contact(payload)
    @payloads << payload.deep_dup
    raise Loops::Client::RequestError.new("Provider rejected contact", status: 400) if payload[:email] == rejected_email
    email = payload.fetch(:email)
    contact = contacts[email] || add(email)
    contact.merge!(payload.except(:mailingLists).stringify_keys)
    payload.fetch(:mailingLists, {}).each do |id, subscribed|
      next if subscribed && list_opt_outs.include?([ email, id ])
      subscribed ? contact["mailingLists"][id] = true : contact["mailingLists"].delete(id)
    end
    { "success" => true, "id" => contact.fetch("id") }
  end

  def send_transactional(payload, idempotency_key:)
    @attempts << [ payload.deep_dup, idempotency_key ]
    return { "success" => true } if @keys[idempotency_key]
    before_send&.call(payload)
    @keys[idempotency_key] = true
    @messages << payload.deep_dup
    if timeout_after_accept
      self.timeout_after_accept = false
      raise Loops::Client::NetworkError, "Synthetic timeout after acceptance"
    end
    { "success" => true }
  end
end
