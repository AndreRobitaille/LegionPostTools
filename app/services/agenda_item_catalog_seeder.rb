class AgendaItemCatalogSeeder
  SOURCE_LABEL = "Officer's Guide regular meeting seed"
  RETIRED_SOURCE_KEYS = %w[
    regular_meeting.closing_ceremony
    regular_meeting.unfinished_old_business
    regular_meeting.new_business_correspondence
  ].freeze
  INSERT_AT_PREFERRED_POSITION_SOURCE_KEYS = %w[
    regular_meeting.closing_memorial_service
    regular_meeting.closing_service_reminder
  ].freeze

  ENTRIES = [
    {
      source_key: "regular_meeting.opening_ceremony",
      title: "Call the Meeting to Order",
      slug: "opening-ceremony",
      summary: "Open the meeting and bring officers and members to order.",
      category: "opening_ceremony",
      behavior_type: "scripted_ceremony",
      position: 1,
      body: "",
      commander_notes: "• The commander announces that the meeting is about to open.\n• Officers take their stations.\n• The commander seats those present with one rap of the gavel.\n• The sergeant-at-arms closes the doors of the meeting hall.\n• The commander gives three raps of the gavel and all present stand at attention.",
      legacy: {
        title: "Opening Ceremony",
        summary: [ "Begins the regular meeting with colors, prayer, POW/MIA recognition, pledge, and preamble.", "" ],
        commander_notes: "• The commander announces that the meeting is about to open.\n• Officers take their stations.\n• The sergeant-at-arms closes the doors of the meeting hall.\n• The commander gives three raps of the gavel and all present stand at attention."
      }
    },
    {
      source_key: "regular_meeting.opening_salute_colors",
      title: "Colors & Hand Salute",
      slug: "opening-hand-salute-and-colors",
      summary: "Honor the colors according to the Post's practice.",
      category: "opening_ceremony",
      behavior_type: "scripted_ceremony",
      position: 2,
      body: "",
      commander_notes: "• The color bearers advance the colors.\n• The commander commands: Hand salute.\n• After the colors are posted, the commander commands: Two."
    },
    {
      source_key: "regular_meeting.opening_prayer",
      title: "Chaplain's Prayer",
      slug: "opening-prayer",
      summary: "The chaplain offers the Post's established opening prayer while members remain uncovered.",
      category: "opening_ceremony",
      behavior_type: "scripted_ceremony",
      position: 3,
      show_wording_on_agenda: false,
      show_wording_in_minutes: false,
      body: "Almighty God, \n\nFather of all mankind and Judge over nations, we pray Thee to guide our work in this meeting and in all our days. Send Thy peace to our nation and to all nations. Hasten the fulfillment of Thy promise of peace that shall have no end. We pray for those who serve the people and guard the public welfare, that by Thy blessing they may be enabled to discharge their duties honestly and well. We pray that by Thy help they may observe the strictest justice, keep alight the fires of freedom, strive earnestly for the spirit of democracy, and preserve untarnished our loyalty to our country and to Thee. Finally, O God of mercy, we ask Thy blessing and comfort for those who are suffering mental and physical disability. Cheer them and bring them the blessings of health and happiness. \n\nAmen.",
      legacy: {
        title: "Opening Prayer",
        summary: "Suggested nonsectarian opening prayer from the regular meeting ceremony."
      }
    },
    {
      source_key: "regular_meeting.pow_mia_empty_chair",
      title: "POW/MIA Empty Chair",
      slug: "pow-mia-empty-chair",
      summary: "Place the POW/MIA flag and recognize American POW/MIAs still unaccounted for.",
      category: "opening_ceremony",
      behavior_type: "scripted_ceremony",
      position: 4,
      body: "",
      commander_notes: "The POW/MIA empty chair is placed at all official meetings of The American Legion as a physical symbol of the many American POW/MIAs still unaccounted for from all wars and conflicts involving the United States of America. This is a reminder for all of us to spare no effort to secure the release of any American prisoners from captivity, the repatriation of the remains of those who died bravely in defense of liberty, and a full accounting of those missing. Let us rededicate ourselves to this vital endeavor.\n\nPlace the POW/MIA flag on the empty chair.",
      legacy: {
        summary: "Recognition of American POW/MIAs still unaccounted for.",
        body: "A POW/MIA empty chair is placed at all official meetings of The American Legion as a physical symbol of many American POW/MIAs still unaccounted for from all wars and conflicts involving the United States of America. This is a reminder for all of us to spare no effort to secure the release of any American prisoners from captivity, the repatriation of the remains of those who died bravely in defense of liberty, and a full accounting of those missing. Let us rededicate ourselves to this vital endeavor!\n\nPlace the POW/MIA flag on the empty chair.",
        commander_notes: "Place the POW/MIA flag on the empty chair.\n\nThe POW/MIA empty chair is placed at all official meetings of The American Legion as a physical symbol of the many American POW/MIAs still unaccounted for from all wars and conflicts involving the United States of America. This is a reminder for all of us to spare no effort to secure the release of any American prisoners from captivity, the repatriation of the remains of those who died bravely in defense of liberty, and a full accounting of those missing. Let us rededicate ourselves to this vital endeavor."
      }
    },
    {
      source_key: "regular_meeting.pledge_of_allegiance",
      title: "Pledge of Allegiance",
      slug: "pledge-of-allegiance",
      summary: "Recite the Pledge of Allegiance.",
      category: "opening_ceremony",
      behavior_type: "reading_recitation",
      position: 5,
      show_wording_on_agenda: false,
      show_wording_in_minutes: false,
      body: "I pledge allegiance to the Flag of the United States of America, and to the Republic for which it stands, one Nation under God, indivisible, with liberty and justice for all.",
      legacy: { summary: [ "The Pledge of Allegiance recited during the opening ceremony.", "Uncover and recite the pledge." ] }
    },
    {
      source_key: "regular_meeting.preamble",
      title: "American Legion Preamble",
      slug: "american-legion-preamble",
      summary: "Re-cover and recite the Preamble to the Constitution of The American Legion.",
      category: "opening_ceremony",
      behavior_type: "reading_recitation",
      position: 6,
      show_wording_in_minutes: false,
      body: "For God and Country, we associate ourselves together for the following purposes:\n\n• To uphold and defend the Constitution of the United States of America;\n• To maintain law and order;\n• To foster and perpetuate a one hundred percent Americanism;\n• To preserve the memories and incidents of our associations in all wars;\n• To inculcate a sense of individual obligation to the community, state and nation;\n• To combat the autocracy of both the classes and the masses;\n• To make right the master of might;\n• To promote peace and good will on earth;\n• To safeguard and transmit to posterity the principles of justice, freedom and democracy;\n• To consecrate and sanctify our comradeship by our devotion to mutual helpfulness.",
      legacy: {
        summary: [ "The Preamble to the Constitution of The American Legion.", "Recover and recite the Preamble to the Constitution of The American Legion." ],
        body: "For God and Country, we associate ourselves together for the following purposes:\n\nTo uphold and defend the Constitution of the United States of America;\nTo maintain law and order;\nTo foster and perpetuate a one hundred percent Americanism;\nTo preserve the memories and incidents of our associations in all wars;\nTo inculcate a sense of individual obligation to the community, state and nation;\nTo combat the autocracy of both the classes and the masses;\nTo make right the master of might;\nTo promote peace and goodwill on earth;\nTo safeguard and transmit to posterity the principles of justice, freedom and democracy;\nTo consecrate and sanctify our comradeship by our devotion to mutual helpfulness."
      }
    },
    {
      source_key: "regular_meeting.opening_declaration",
      title: "Declare the Post in Session",
      slug: "declare-the-post-in-session",
      summary: "The commander's declaration marks the transition from ceremony to the order of business.",
      category: "opening_ceremony",
      behavior_type: "scripted_ceremony",
      position: 7,
      body: "",
      commander_notes: "The commander gives one rap of the gavel and declares the Post in session using the Post's full name and Department."
    },
    {
      source_key: "regular_meeting.closing_memorial_service",
      title: "Closing Memorial Service",
      slug: "closing-memorial-service",
      summary: "Remember departed members, POWs, and MIAs before concluding the meeting.",
      category: "closing_ceremony",
      behavior_type: "scripted_ceremony",
      position: 1,
      body: "",
      commander_notes: "The commander asks whether there is any further business. If not, the chaplain leads the memorial service. The commander gives three raps of the gavel. The membership rises, uncovers, and stands in silence while the chaplain offers the Post's established memorial prayer."
    },
    {
      source_key: "regular_meeting.closing_service_reminder",
      title: "Service and Citizenship Reminder",
      slug: "closing-service-and-citizenship-reminder",
      summary: "Recall The American Legion's obligation to country, community, and democratic principles.",
      category: "closing_ceremony",
      behavior_type: "scripted_ceremony",
      position: 2,
      body: "",
      commander_notes: "Till we meet again, let us remember that our obligation to our country can be fulfilled only by the faithful performance of all duties of citizenship. Let service to community, state, and nation be ever a main objective of The American Legion and its members. Let us be ever watchful of the honor of our country, our organization, and ourselves, that nothing shall swerve us from the path of justice, freedom, and democracy."
    },
    {
      source_key: "regular_meeting.pow_mia_flag_retrieval",
      title: "Retrieve the POW/MIA Flag",
      slug: "retrieve-the-pow-mia-flag",
      summary: "Recover the POW/MIA flag as part of the closing ceremony.",
      category: "closing_ceremony",
      behavior_type: "scripted_ceremony",
      position: 3,
      body: "",
      commander_notes: "The commander directs the sergeant-at-arms to recover the POW/MIA flag."
    },
    {
      source_key: "regular_meeting.closing_salute_colors",
      title: "Hand Salute & Retire Colors",
      slug: "closing-hand-salute-and-colors",
      summary: "Honor or retire the colors according to the Post's closing practice.",
      category: "closing_ceremony",
      behavior_type: "scripted_ceremony",
      position: 4,
      body: "",
      commander_notes: "• All present face the American flag.\n• The commander commands: Hand salute.\n• The color bearers retire the colors as applicable.\n• The commander then commands: Two."
    },
    {
      source_key: "regular_meeting.adjournment_declaration",
      title: "Declare the Meeting Adjourned",
      slug: "declare-the-meeting-adjourned",
      summary: "The commander formally adjourns the meeting and gives one rap of the gavel.",
      category: "closing_ceremony",
      behavior_type: "scripted_ceremony",
      position: 5,
      body: "",
      commander_notes: "The commander declares the meeting adjourned using the Post's established wording, then gives one rap of the gavel."
    },
    {
      source_key: "regular_meeting.roll_call_quorum",
      title: "Roll Call and Quorum",
      slug: "roll-call-and-quorum",
      summary: "List the Post officers, record their attendance, and determine whether a quorum is present before conducting official business.",
      category: "call_to_order",
      behavior_type: "roll_call",
      position: 1,
      body: "",
      legacy: {
        summary: "Determine whether enough members are present to conduct authorized business.",
        body: "Roll call to determine if a quorum is present before conducting official business.",
        behavior_type: "business_item"
      }
    },
    {
      source_key: "regular_meeting.previous_minutes",
      title: "Approval of Minutes",
      slug: "previous-meeting-minutes",
      summary: "The adjutant presents the minutes of the previous meeting. The chair asks for corrections. If there are no corrections, the minutes stand approved as presented; if corrected, they stand approved as corrected.",
      category: "call_to_order",
      behavior_type: "motion_vote_item",
      position: 2,
      body: "",
      legacy: {
        title: "Previous Meeting Minutes",
        summary: "Read, correct, and approve the previous meeting minutes.",
        body: "The adjutant reads the minutes of the previous meeting. The chair asks for corrections. If there are no corrections, the minutes stand approved as read; if corrected, they stand approved as corrected."
      }
    },
    {
      source_key: "regular_meeting.introductions",
      title: "Guests and New Members",
      slug: "introduction-of-guests-and-prospective-new-members",
      summary: "Introduce and welcome guests, prospective members, and new members.",
      category: "call_to_order",
      behavior_type: "business_item",
      position: 3,
      body: "",
      legacy: {
        title: "Introduction of Guests and Prospective/New Members",
        summary: "Welcome guests, prospective members, and new members.",
        body: "Introduce guests, prospective members, and new members so they are recognized and welcomed by the post."
      }
    },
    {
      source_key: "regular_meeting.finance_officer_report",
      title: "Finance Officer Report",
      slug: "finance-officer-report",
      summary: "The Finance Officer reports on Post finances and matters within that office.",
      category: "reports",
      behavior_type: "report_slot",
      position: 1,
      body: ""
    },
    {
      source_key: "regular_meeting.adjutant_report",
      title: "Adjutant Report",
      slug: "adjutant-report",
      summary: "The adjutant reports on records, correspondence, and matters within that office.",
      category: "reports",
      behavior_type: "report_slot",
      position: 2,
      body: ""
    },
    {
      source_key: "regular_meeting.commander_report",
      title: "Commander Report",
      slug: "commander-report",
      summary: "The commander reports significant Post, PEC, Department, and community developments.",
      category: "reports",
      behavior_type: "report_slot",
      position: 3,
      body: ""
    },
    {
      source_key: "regular_meeting.historian_report",
      title: "Historian Report",
      slug: "historian-report",
      summary: "The historian reports on preserving and documenting the Post's activities.",
      category: "reports",
      behavior_type: "report_slot",
      position: 4,
      body: ""
    },
    {
      source_key: "regular_meeting.chaplain_honor_guard_report",
      title: "Chaplain / Honor Guard Report",
      slug: "chaplain-and-honor-guard-report",
      summary: "Report departed members, memorial observances, and Honor Guard activity.",
      category: "reports",
      behavior_type: "report_slot",
      position: 5,
      body: ""
    },
    {
      source_key: "regular_meeting.programs_activities",
      title: "Programs & Activities",
      slug: "programs-and-activities",
      summary: "Status reports from recurring Post projects, committees, programs, fundraisers, and events.",
      category: "reports",
      behavior_type: "report_slot",
      position: 6,
      body: ""
    },
    {
      source_key: "regular_meeting.committee_reports",
      title: "Committee Reports",
      slug: "committee-reports",
      summary: "List committees scheduled to report. Confirm that a chairperson is ready before placing the report on the agenda.",
      category: "reports",
      behavior_type: "report_slot",
      position: 7,
      body: ""
    },
    {
      source_key: "regular_meeting.balloting_on_applications",
      title: "Balloting on Applications",
      slug: "balloting-on-applications",
      summary: "Ballot on applications for membership according to the Post constitution, by-laws, and applicable American Legion procedures.",
      category: "new_business",
      behavior_type: "motion_vote_item",
      position: 1,
      body: "",
      legacy: {
        summary: "Act on membership applications when required by post procedure.",
        body: "Ballot on applications for membership according to the post constitution, by-laws, and applicable American Legion procedures."
      }
    },
    {
      source_key: "regular_meeting.sick_call_relief_employment",
      title: "Sick Call",
      slug: "sick-call-relief-and-employment",
      summary: "Identify members or other veterans who are sick, hospitalized, deceased, experiencing hardship, or in need of assistance.",
      category: "service_and_welfare",
      behavior_type: "business_item",
      position: 1,
      body: "",
      legacy: {
        title: "Sick Call, Relief, and Employment",
        summary: "Share member welfare, relief, employment, or assistance needs.",
        body: "Use this time for sick call, relief, employment, and other member welfare matters appropriate for the meeting."
      }
    },
    {
      source_key: "regular_meeting.service_officer_report",
      title: "Service Officer Report",
      slug: "post-service-officer-report",
      summary: "The Service Officer reports on veteran assistance, benefits awareness, claims support, referrals, and related service work.",
      category: "service_and_welfare",
      behavior_type: "report_slot",
      position: 2,
      body: "",
      legacy: {
        title: "Post Service Officer Report",
        summary: "Standard report from the post service officer.",
        body: "The post service officer reports on veteran service matters, benefits awareness, claims support, and related assistance."
      }
    },
    {
      source_key: "regular_meeting.memorial_departed_member",
      title: "Memorial to a Departed Post Member",
      slug: "memorial-to-a-departed-post-member",
      summary: "Use this item when the Post needs to recognize a departed member during the regular meeting. The Post may use an appropriate memorial, charter-draping, or Post Everlasting ceremony when applicable.",
      category: "special",
      behavior_type: "scripted_ceremony",
      position: 1,
      body: "",
      legacy: {
        summary: "Memorial recognition for a departed post member when needed.",
        body: "Use this item when the post needs to recognize a departed member during the regular meeting. The post may use an appropriate memorial, charter-draping, or Post Everlasting ceremony when applicable."
      }
    },
    {
      source_key: "regular_meeting.good_of_legion",
      title: "Good of The American Legion",
      slug: "good-of-the-american-legion",
      summary: "Members may raise comments, concerns, recognition, suggestions, or other matters for the good of the Post and The American Legion, excluding religion and partisan politics.",
      category: "good_of_legion",
      behavior_type: "business_item",
      position: 1,
      body: "",
      legacy: {
        summary: "Suggestions and remarks for the good of The American Legion.",
        body: "Members may make suggestions of any kind, character, or description, save religion or partisan politics."
      }
    },
    {
      source_key: "regular_meeting.announcements",
      title: "Announcements",
      slug: "announcements",
      summary: "Announce upcoming Post, County, District, Department, and community events; meeting reminders; deadlines; locations; and volunteer instructions.",
      category: "good_of_legion",
      behavior_type: "business_item",
      position: 2,
      body: ""
    }
  ].freeze

  def self.seed_for!(organization)
    new(organization).seed!
  end

  def initialize(organization)
    @organization = organization
  end

  def seed!
    seeded_at = Time.current

    @organization.agenda_item_catalog_entries.transaction do
      retire_obsolete_entries

      ENTRIES.each do |entry_attributes|
        entry = @organization.agenda_item_catalog_entries.find_by(source_key: entry_attributes.fetch(:source_key))
        if entry
          upgrade_untouched_fields(entry, entry_attributes)
          next
        end

        if entry_attributes.fetch(:source_key).in?(INSERT_AT_PREFERRED_POSITION_SOURCE_KEYS)
          reserve_position(entry_attributes.fetch(:category), entry_attributes.fetch(:position))
        end
        @organization.agenda_item_catalog_entries.create!(
          entry_attributes.except(:body, :commander_notes, :legacy).merge(
            active: true,
            source_label: SOURCE_LABEL,
            seeded_at: seeded_at,
            body: entry_attributes.fetch(:body),
            commander_notes: entry_attributes.fetch(:commander_notes, "")
          )
        )
      end
    end
  end

  private

  def retire_obsolete_entries
    @organization.agenda_item_catalog_entries.kept
      .where(source_label: SOURCE_LABEL, source_key: RETIRED_SOURCE_KEYS)
      .find_each(&:remove_from_catalog!)
  end

  def reserve_position(category, position)
    @organization.agenda_item_catalog_entries.kept
      .where(category: category)
      .where("position >= ?", position)
      .order(position: :desc, id: :desc)
      .each { |entry| entry.update!(position: entry.position + 1) }
  end

  def upgrade_untouched_fields(entry, entry_attributes)
    legacy_attributes = entry_attributes[:legacy]
    return if legacy_attributes.blank? || entry.source_label != SOURCE_LABEL

    updates = legacy_attributes.each_with_object({}) do |(attribute, old_value), result|
      current_value = rich_text_value(entry, attribute)
      old_values = old_value.is_a?(Array) ? old_value : [ old_value ]
      result[attribute] = entry_attributes.fetch(attribute) if old_values.any? { |value| comparable(current_value) == comparable(value) }
    end
    entry.update!(updates) if updates.any?
  end

  def comparable(value)
    value.to_s.strip.gsub(/\r\n?/, "\n")
  end

  def rich_text_value(entry, attribute)
    return entry.public_send(attribute).to_plain_text if attribute.in?(%i[body commander_notes])

    entry.public_send(attribute)
  end
end
