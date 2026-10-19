module MinutesDistributionData
  def self.included(test_case)
    test_case.include ActiveJob::TestHelper
  end

  attr_reader :organization, :body, :type, :minutes, :officer, :provider, :recipient

  def setup_distribution
    @organization = Organization.create!(name: "Synthetic Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @body = organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @type = organization.meeting_types.create!(name: "Monthly membership meeting", slug: "monthly", active: true, position: 1)
    meeting = create_meeting!(organization:, meeting_body: body, meeting_type: type, starts_at: 2.days.ago)
    @minutes = MeetingMinutes.create_from_meeting!(meeting:)
    @item = minutes.sections.first.items.create!(title: "Finance", behavior_type: "report_slot", position: 1, body: "Balance: $100.")
    person = Person.create!(first_name: "Synthetic", last_name: "Adjutant")
    @officer = User.create!(person:, email_address: "synthetic-adjutant@example.test", email_verified_at: Time.current)
    %w[attest_minutes manage_minutes record_minutes_approval manage_settings].each { |capability| officer.permission_grants.create!(capability:) }
    organization.create_minutes_distribution_setting!(post_members_list_id: "members", minutes_recipients_list_id: "minutes",
      template_id: "minutes-template", reply_to: "reply@example.test", meeting_type_ids: [ type.id ], audiences_reviewed: true, enabled: true)
    @provider = MinutesDistributionProvider.new
    @recipient = add_recipient("county@example.test", office: "County Commander")
  end

  def add_recipient(email, office:, name: "Synthetic Officer")
    contact = provider.contacts[email] || provider.add(email, mailingLists: { "minutes" => true })
    organization.minutes_recipients.create!(name:, office:, email:, loops_contact_id: contact.fetch("id"),
      enrolled_list_id: "minutes", enrollment_status: "enrolled")
  end

  def official_action(action, payload = {})
    confirmation = OfficialActionConfirmation.record_external!(minutes: minutes.reload, user: officer, action:,
      action_payload: payload, evidence_note: "Synthetic offline workflow.")
    case action
    when "attest" then minutes.attest_with_confirmation!(confirmation:)
    when "reopen" then minutes.reopen_with_confirmation!(confirmation:)
    when "record_membership_approval" then minutes.record_membership_approval_with_confirmation!(confirmation:)
    end
  end

  def attest
    official_action("attest")
    minutes.email_distributions.order(:id).last
  end

  def correct(text)
    official_action("reopen", reason: "Correct the recorded balance.")
    @item.reload.update!(body: text)
    attest
  end

  def approve(corrections_pending: false)
    later = create_meeting!(organization:, meeting_body: body, starts_at: 1.hour.ago)
    official_action("record_membership_approval", approving_meeting_id: later.id,
      disposition: corrections_pending ? "approved_as_corrected" : "approved_as_presented",
      corrections_pending:, factual_note: corrections_pending ? "Balance should be $101." : nil)
  end

  def with_distribution_method(klass, name, replacement)
    original = klass.method(name)
    klass.define_singleton_method(name, replacement)
    yield
  ensure
    klass.define_singleton_method(name, original)
  end

  class Renderer
    def self.render_distribution(issue:)
      "%PDF-1.7\nSynthetic #{issue.minutes_revision.payload.to_json}\n#{issue.document_context.to_json}"
    end
  end

  def dispatch(issue)
    MinutesDistribution::Processor.new(issue, client: provider, renderer: Renderer).call
  end
end
