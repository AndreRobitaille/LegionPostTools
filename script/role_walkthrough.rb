# Run through bin/role-walkthrough. Never use development or member data.
require "fileutils"

raise "Isolated role walkthrough database required" unless Rails.env.test? &&
  ActiveRecord::Base.connection_db_config.database == "legion_post_tools_role_walkthrough_test"

output = File.expand_path(ENV.fetch("ROLE_WALKTHROUGH_OUTPUT", "/tmp/legion-role-walkthrough"))
FileUtils.mkdir_p(output, mode: 0o700)
organization = Organization.first
raise "Unexpected records in walkthrough database" if organization && organization.name != "Harbor Post 204 (synthetic walkthrough)"

def walkthrough_source_digests
  [ AgendaItemCatalogEntry, MeetingTypeAgendaItem ].to_h do |model|
    records = model.order(:id).includes(:rich_text_body, :rich_text_commander_notes).map do |record|
      attributes = record.attributes.except("created_at", "updated_at").transform_values do |value|
        value.respond_to?(:utc) ? value.utc.iso8601(6) : value
      end
      attributes.merge("body" => record.body.to_s, "commander_notes" => record.commander_notes.to_s)
    end
    [ model.name, Digest::SHA256.hexdigest(JSON.generate(records)) ]
  end
end

case ARGV.first
when "prepare"
  if organization
    raise "Existing pilot is missing its scenario; use its original output directory" unless File.exist?(File.join(output, "scenario.json"))
    puts "Existing synthetic pilot preserved: #{output}"
    exit
  end
  raise "Unexpected people in walkthrough database" if Person.exists?

  scenario = ApplicationRecord.transaction do
    organization = Organization.create!(name: "Harbor Post 204 (synthetic walkthrough)", unit_type: "american_legion_post",
      timezone: "America/Chicago", default_location_name: "Fictional Harbor Hall", default_location_address: "Example location only")
    Installation.singleton.update!(setup_completed_at: Time.current)
    AmericanLegionPostPreset.apply_to(organization)
    AgendaItemCatalogSeeder.seed_for!(organization)
    MeetingTypeTemplateSeeder.seed_for!(organization)
    today = organization.calendar_time_zone.today
    actors = { commander: [ "Casey", "Morgan" ], adjutant: [ "Jordan", "Ellis" ],
      administrator: [ "Avery", "Chen" ], member: [ "Taylor", "Rivera" ], incoming: [ "Riley", "Brooks" ] }.to_h do |role, names|
      person = Person.create!(first_name: names.first, last_name: names.last)
      user = User.create!(person:, email_address: "#{role}@example.test", email_verified_at: Time.current)
      [ role, user ]
    end
    { commander: "Commander", adjutant: "Adjutant" }.each do |role, office|
      organization.position_titles.find_by!(name: office).position_assignments.create!(person: actors.fetch(role).person, starts_on: today - 1.year)
    end
    actors.fetch(:administrator).permission_grants.create!(capability: "manage_settings")
    body = organization.meeting_bodies.find_by!(slug: "membership")
    type = organization.meeting_types.find_by!(source_key: "american_legion_post:membership_meeting")
    meetings = { recent: [ today - 2.days, "Harbor membership meeting" ], approving: [ today - 1.day, "Harbor special membership meeting" ],
      next: [ today.next_occurring(:thursday), "Next Harbor membership meeting" ], direct: [ today - 3.days, "Adjutant-originated meeting" ] }.to_h do |key, (date, title)|
      [ key, organization.meetings.create!(meeting_body: body, meeting_type: type, title:,
        starts_at: organization.calendar_time_zone.local(date.year, date.month, date.day, 19)) ]
    end
    agenda = DatedAgenda.create_from_template!(meeting: meetings.fetch(:recent))
    section = agenda.dated_agenda_sections.find_by!(title: "New Business")
    section.agenda_items.create!(dated_agenda: agenda, title: "Community breakfast planning", behavior_type: "business_item", position: section.agenda_items.maximum(:position).to_i + 1,
      body: "Discuss whether to explore a community breakfast and return with possible dates.")
    agenda.approve!(actors.fetch(:commander))
    agenda.publish!(actors.fetch(:commander))
    MeetingMinutes.create_from_meeting!(meeting: meetings.fetch(:recent))
    MeetingMinutes.create_from_meeting!(meeting: meetings.fetch(:direct))
    RosterImport.create!(uploaded_filename: "synthetic-initial-roster.csv", status: "completed", imported_at: 35.days.ago)
    {
      synthetic: true, today: today.iso8601, origin: "http://localhost:#{Integer(ENV.fetch('ROLE_WALKTHROUGH_PORT', '3095'))}",
      actors: actors.transform_values { |user| { name: user.person.full_name, email: user.email_address } },
      meetings: meetings.transform_values { |meeting| { title: meeting.title, date: meeting.starts_at.in_time_zone(organization.calendar_time_zone).to_date.iso8601 } },
      facts: {
        recent: "All listed ceremonies and reports proceeded without additional business. Casey Morgan and Jordan Ellis were present; other offices were vacant. Members discussed exploring a community breakfast. No motion or vote was taken. Jordan will bring possible dates to the next meeting. The meeting adjourned at 8:00 PM.",
        next_agenda: "Add a meeting-specific discussion: Community breakfast follow-up. Details: Jordan will bring possible dates; members will decide whether to proceed. Keep this a discussion, without creating an Endeavor or changing the reusable template.",
        adjutant_review: "Before attesting, change the recent record's document title to Harbor membership meeting — reviewed minutes. This is a document correction, not a change to the meeting itself.",
        later_approval: "At the seeded later special membership meeting, the same meeting body approved the recent minutes with corrections. The only requested correction is its document title: Harbor membership meeting — corrected minutes. This is a synthetic decision supplied for the exercise.",
        direct: "For the Adjutant-originated meeting, record: Members discussed preparations for Veterans Day. No motion or vote was taken. The meeting adjourned at 7:45 PM. Attest directly; no Commander handoff was requested.",
        turnover: "After both records are finished, Jordan's Adjutant term ends #{(today - 1.day).iso8601}. Riley's term begins #{today.iso8601}. Keep their login accounts and existing official records. Assign dated roles, with no permanent manual officer grants."
      }
    }
  end
  File.write(File.join(output, "scenario.json"), JSON.pretty_generate(scenario), mode: "w", perm: 0o600)
  baseline = { template_ids: MeetingTypeAgendaItem.order(:id).pluck(:id), catalog_ids: AgendaItemCatalogEntry.order(:id).pluck(:id),
    endeavor_count: Endeavor.count, meeting_ids: Meeting.order(:id).pluck(:id), source_digests: walkthrough_source_digests }
  File.write(File.join(output, "baseline.json"), JSON.pretty_generate(baseline), mode: "w", perm: 0o600)
  puts "Synthetic role walkthrough prepared: #{output}"
when "inspect"
  raise "Prepare the synthetic pilot first" unless organization
  evidence = {
    database: ActiveRecord::Base.connection_db_config.database, synthetic: true,
    application_time_zone: Rails.application.config.time_zone, post_time_zone: organization.timezone,
    actors: User.includes(person: { position_assignments: :position_title }).order(:id).map do |user|
      { email: user.email_address, settings: user.can?("manage_settings"), agendas: user.can?("manage_agendas"),
        minutes: user.can?("manage_minutes"), attest: user.can?("attest_minutes"), manual_grants: user.permission_grants.pluck(:capability),
        terms: user.person.position_assignments.map { |term| { office: term.position_title.name, start: term.starts_on, end: term.ends_on } } }
    end,
    meetings: Meeting.order(:id).map do |meeting|
      minutes = meeting.minutes
      { id: meeting.id, title: meeting.title, starts_at_utc: meeting.starts_at.utc.iso8601, meeting_body_id: meeting.meeting_body_id,
        agenda_status: meeting.dated_agenda&.status,
        agenda_items: meeting.dated_agenda&.dated_agenda_items&.map { |item| { title: item.title, body: item.body.to_plain_text } },
        minutes_status: minutes&.status, minutes_title: minutes&.title, member_title: minutes&.member_revision&.payload&.fetch("title"),
        items: minutes&.items&.map { |item| { title: item.title, body: item.body.to_plain_text } },
        revisions: minutes&.revisions&.map { |revision| { id: revision.id, title: revision.payload.fetch("title"), sha256: revision.sha256,
          # JSONB may reorder keys. This read-back digest compares later stored snapshots;
          # it is separate from the document's original capture digest above.
          stored_payload_sha256: Digest::SHA256.hexdigest(JSON.generate(revision.payload)),
          commander_id: revision.approved_by_id, adjutant_id: revision.attestation&.attested_by_id } },
        events: minutes&.lifecycle_events&.map { |event| { type: event.event_type, actor: event.actor_id, from: event.from_status, to: event.to_status, metadata: event.metadata } },
        approving_meeting_id: minutes&.membership_approval&.approving_meeting_id }
    end,
    catalog_count: AgendaItemCatalogEntry.count, template_count: MeetingTypeAgendaItem.count, endeavor_count: Endeavor.count,
    paid_draft_runs: MinutesDraftRun.count, source_digests: walkthrough_source_digests
  }
  puts JSON.pretty_generate(evidence)
else
  raise "Use bin/role-walkthrough prepare|inspect"
end
