class AgendaItemCatalogSeeder
  SOURCE_LABEL = "Officer's Guide regular meeting seed"

  ENTRIES = [
    {
      source_key: "regular_meeting.opening_ceremony",
      title: "Opening Ceremony",
      slug: "opening-ceremony",
      summary: "A compact opening sequence for Posts that keep the ceremony in one agenda item.",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      body: "The commander announces that the meeting is about to open. Officers take their stations. The sergeant-at-arms closes the doors of the meeting hall. The commander gives three raps of the gavel and all present stand at attention. The color bearers advance the colors. The commander commands: Hand salute. After the colors are posted, the commander commands: Two. The chaplain offers prayer. The meeting continues with the POW/MIA Empty Chair ceremony, Pledge of Allegiance, and American Legion Preamble.",
      legacy: { summary: "Begins the regular meeting with colors, prayer, POW/MIA recognition, pledge, and preamble." }
    },
    {
      source_key: "regular_meeting.opening_salute_colors",
      title: "Hand Salute / Colors",
      slug: "opening-hand-salute-and-colors",
      summary: "Open the meeting, bring members to attention, and honor the colors according to the Post's practice.",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      body: "The commander announces that the meeting is about to open. Officers take their stations. The sergeant-at-arms closes the doors of the meeting hall. The commander gives three raps of the gavel and all present stand at attention. The color bearers advance the colors as applicable. The commander commands: Hand salute. After the colors are posted, the commander commands: Two."
    },
    {
      source_key: "regular_meeting.opening_prayer",
      title: "Chaplain's Prayer",
      slug: "opening-prayer",
      summary: "The chaplain offers the Post's established opening prayer while members remain uncovered.",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      body: "Almighty God, Father of all mankind and Judge over nations, we pray Thee to guide our work in this meeting and in all our days. Send Thy peace to our nation and to all nations. Hasten the fulfillment of Thy promise of peace that shall have no end.\n\nWe pray for those who serve the people and guard the public welfare, that by Thy blessing they may be enabled to discharge their duties honestly and well. We pray that by Thy help they may observe the strictest justice, keep alight the fires of freedom, strive earnestly for the spirit of democracy, and preserve untarnished our loyalty to our country and to Thee. Finally, O God of mercy, we ask Thy blessing and comfort for those who are suffering mental and physical disability. Cheer them and bring them the blessings of health and happiness. Amen.",
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
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      body: "Place the POW/MIA flag on the empty chair.\n\nThe POW/MIA empty chair is placed at all official meetings of The American Legion as a physical symbol of the many American POW/MIAs still unaccounted for from all wars and conflicts involving the United States of America. This is a reminder for all of us to spare no effort to secure the release of any American prisoners from captivity, the repatriation of the remains of those who died bravely in defense of liberty, and a full accounting of those missing. Let us rededicate ourselves to this vital endeavor.",
      legacy: {
        summary: "Recognition of American POW/MIAs still unaccounted for.",
        body: "A POW/MIA empty chair is placed at all official meetings of The American Legion as a physical symbol of many American POW/MIAs still unaccounted for from all wars and conflicts involving the United States of America. This is a reminder for all of us to spare no effort to secure the release of any American prisoners from captivity, the repatriation of the remains of those who died bravely in defense of liberty, and a full accounting of those missing. Let us rededicate ourselves to this vital endeavor!\n\nPlace the POW/MIA flag on the empty chair."
      }
    },
    {
      source_key: "regular_meeting.pledge_of_allegiance",
      title: "Pledge of Allegiance",
      slug: "pledge-of-allegiance",
      summary: "Recite the Pledge of Allegiance during the opening ceremony.",
      category: "ceremony",
      behavior_type: "reading_recitation",
      body: "I pledge allegiance to the Flag of the United States of America and to the Republic for which it stands, one Nation under God, indivisible, with liberty and justice for all.",
      legacy: { summary: "The Pledge of Allegiance recited during the opening ceremony." }
    },
    {
      source_key: "regular_meeting.preamble",
      title: "American Legion Preamble",
      slug: "american-legion-preamble",
      summary: "Recite the Preamble to the Constitution of The American Legion.",
      category: "ceremony",
      behavior_type: "reading_recitation",
      body: "For God and Country, we associate ourselves together for the following purposes:\n\nTo uphold and defend the Constitution of the United States of America;\nTo maintain law and order;\nTo foster and perpetuate a one hundred percent Americanism;\nTo preserve the memories and incidents of our associations in all wars;\nTo inculcate a sense of individual obligation to the community, state and nation;\nTo combat the autocracy of both the classes and the masses;\nTo make right the master of might;\nTo promote peace and good will on earth;\nTo safeguard and transmit to posterity the principles of justice, freedom and democracy;\nTo consecrate and sanctify our comradeship by our devotion to mutual helpfulness.",
      legacy: {
        summary: "The Preamble to the Constitution of The American Legion.",
        body: "For God and Country, we associate ourselves together for the following purposes:\n\nTo uphold and defend the Constitution of the United States of America;\nTo maintain law and order;\nTo foster and perpetuate a one hundred percent Americanism;\nTo preserve the memories and incidents of our associations in all wars;\nTo inculcate a sense of individual obligation to the community, state and nation;\nTo combat the autocracy of both the classes and the masses;\nTo make right the master of might;\nTo promote peace and goodwill on earth;\nTo safeguard and transmit to posterity the principles of justice, freedom and democracy;\nTo consecrate and sanctify our comradeship by our devotion to mutual helpfulness."
      }
    },
    {
      source_key: "regular_meeting.opening_declaration",
      title: "Declare the Post in Session",
      slug: "declare-the-post-in-session",
      summary: "The commander's declaration marks the transition from ceremony to the order of business.",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      body: "The commander gives one rap of the gavel and declares the Post in session using the Post's full name and Department."
    },
    {
      source_key: "regular_meeting.closing_ceremony",
      title: "Closing Ceremony",
      slug: "closing-ceremony",
      summary: "A compact closing sequence for Posts that keep the ceremony in one agenda item.",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      body: "The commander asks: Is there any further business to come before the meeting? If not, the chaplain will lead us in memorial service.\n\nThe membership rises, uncovers, and stands in silence. The chaplain offers the memorial prayer. The commander directs the sergeant-at-arms to recover the POW/MIA flag. The commander reminds members that service to community, state, and nation is a main objective of The American Legion. The color bearers retire the flag of our country. The commander declares the meeting adjourned with one rap of the gavel.",
      legacy: { summary: "Closes the regular meeting with memorial service, POW/MIA flag recovery, colors, and adjournment." }
    },
    {
      source_key: "regular_meeting.pow_mia_flag_retrieval",
      title: "Retrieve the POW/MIA Flag",
      slug: "retrieve-the-pow-mia-flag",
      summary: "Recover the POW/MIA flag as part of the closing ceremony.",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      body: "The commander directs the sergeant-at-arms to recover the POW/MIA flag."
    },
    {
      source_key: "regular_meeting.closing_salute_colors",
      title: "Hand Salute / Colors",
      slug: "closing-hand-salute-and-colors",
      summary: "Honor or retire the colors according to the Post's closing practice.",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      body: "All present face the American flag. The commander commands: Hand salute. The color bearers retire the colors as applicable. The commander then commands: Two."
    },
    {
      source_key: "regular_meeting.adjournment_declaration",
      title: "Declare the Meeting Adjourned",
      slug: "declare-the-meeting-adjourned",
      summary: "The commander formally adjourns the meeting and gives one rap of the gavel.",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      body: "The commander declares the meeting adjourned using the Post's established wording, then gives one rap of the gavel."
    },
    {
      source_key: "regular_meeting.roll_call_quorum",
      title: "Roll Call and Quorum",
      slug: "roll-call-and-quorum",
      summary: "Call the Post officers and determine whether a quorum is present.",
      category: "administration",
      behavior_type: "roll_call",
      body: "List the Post officers, record their attendance, and determine whether a quorum is present before conducting official business.",
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
      summary: "Review, correct, and approve the previous meeting's minutes.",
      category: "administration",
      behavior_type: "motion_vote_item",
      body: "The adjutant presents the minutes of the previous meeting. The chair asks for corrections. If there are no corrections, the minutes stand approved as presented; if corrected, they stand approved as corrected.",
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
      category: "membership",
      behavior_type: "business_item",
      body: "Introduce guests, prospective members, and new members so they are recognized and welcomed by the Post.",
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
      body: "Finance Officer report."
    },
    {
      source_key: "regular_meeting.adjutant_report",
      title: "Adjutant Report",
      slug: "adjutant-report",
      summary: "The adjutant reports on records, correspondence, and matters within that office.",
      category: "reports",
      behavior_type: "report_slot",
      body: "Adjutant report and correspondence."
    },
    {
      source_key: "regular_meeting.commander_report",
      title: "Commander Report",
      slug: "commander-report",
      summary: "The commander reports significant Post, PEC, Department, and community developments.",
      category: "reports",
      behavior_type: "report_slot",
      body: "Commander report."
    },
    {
      source_key: "regular_meeting.historian_report",
      title: "Historian Report",
      slug: "historian-report",
      summary: "The historian reports on preserving and documenting the Post's activities.",
      category: "reports",
      behavior_type: "report_slot",
      body: "Historian report."
    },
    {
      source_key: "regular_meeting.chaplain_honor_guard_report",
      title: "Chaplain / Honor Guard Report",
      slug: "chaplain-and-honor-guard-report",
      summary: "Report departed members, memorial observances, and Honor Guard activity.",
      category: "reports",
      behavior_type: "report_slot",
      body: "Departed members, memorial observances, and Honor Guard activity."
    },
    {
      source_key: "regular_meeting.programs_activities",
      title: "Programs & Activities",
      slug: "programs-and-activities",
      summary: "Status reports from recurring Post projects, committees, programs, fundraisers, and events.",
      category: "reports",
      behavior_type: "report_slot",
      body: "Report ongoing Post programs and activities. Put any new decision or requested authorization in New Business."
    },
    {
      source_key: "regular_meeting.committee_reports",
      title: "Committee Reports",
      slug: "committee-reports",
      summary: "Reports from standing or special committees scheduled to report.",
      category: "reports",
      behavior_type: "section_heading",
      body: "List committees scheduled to report. Confirm that a chairperson is ready before placing the report on the agenda."
    },
    {
      source_key: "regular_meeting.balloting_on_applications",
      title: "Balloting on Applications",
      slug: "balloting-on-applications",
      summary: "Act on membership applications when required by Post procedure.",
      category: "membership",
      behavior_type: "motion_vote_item",
      body: "Ballot on applications for membership according to the Post constitution, by-laws, and applicable American Legion procedures.",
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
      category: "business",
      behavior_type: "business_item",
      body: "Are any members or other veterans sick, hospitalized, deceased, experiencing hardship, or otherwise in need of assistance?",
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
      summary: "Report veteran assistance, benefits, claims, referrals, and other service work.",
      category: "reports",
      behavior_type: "report_slot",
      body: "The Service Officer reports on veteran assistance, benefits awareness, claims support, referrals, and related service work.",
      legacy: {
        title: "Post Service Officer Report",
        summary: "Standard report from the post service officer.",
        body: "The post service officer reports on veteran service matters, benefits awareness, claims support, and related assistance."
      }
    },
    {
      source_key: "regular_meeting.unfinished_old_business",
      title: "Unfinished Business",
      slug: "unfinished-old-business",
      summary: "A specific motion, proposal, or decision left unresolved from an earlier meeting.",
      category: "business",
      behavior_type: "section_heading",
      body: "List only business on which the membership still owes a decision. An ongoing project or another status update belongs under Programs & Activities instead.",
      legacy: {
        title: "Unfinished / Old Business",
        summary: "Business carried over from earlier meetings.",
        body: "Bring forward business postponed from previous meetings or matters introduced earlier where action was not completed."
      }
    },
    {
      source_key: "regular_meeting.new_business_correspondence",
      title: "New Business",
      slug: "new-business-and-correspondence",
      summary: "New matters that require membership consideration, authorization, or a decision.",
      category: "business",
      behavior_type: "section_heading",
      body: "List new matters that require deliberation, authorization, or a decision. Informational correspondence, dates, and reminders belong under Reports or Announcements.",
      legacy: {
        title: "New Business and Correspondence",
        summary: "New business, correspondence, and motions for post action.",
        body: "Introduce new business, communications, correspondence, and motions calling for action by the post."
      }
    },
    {
      source_key: "regular_meeting.memorial_departed_member",
      title: "Memorial to a Departed Post Member",
      slug: "memorial-to-a-departed-post-member",
      summary: "Memorial recognition for a departed Post member when needed.",
      category: "memorial",
      behavior_type: "scripted_ceremony",
      body: "Use this item when the Post needs to recognize a departed member during the regular meeting. The Post may use an appropriate memorial, charter-draping, or Post Everlasting ceremony when applicable.",
      legacy: {
        summary: "Memorial recognition for a departed post member when needed.",
        body: "Use this item when the post needs to recognize a departed member during the regular meeting. The post may use an appropriate memorial, charter-draping, or Post Everlasting ceremony when applicable."
      }
    },
    {
      source_key: "regular_meeting.good_of_legion",
      title: "Good of The American Legion",
      slug: "good-of-the-american-legion",
      summary: "Invite member comments, concerns, recognition, and suggestions for the good of the Post and The American Legion.",
      category: "business",
      behavior_type: "business_item",
      body: "Members may raise comments, concerns, recognition, suggestions, or other matters for the good of the Post and The American Legion, excluding religion and partisan politics.",
      legacy: {
        summary: "Suggestions and remarks for the good of The American Legion.",
        body: "Members may make suggestions of any kind, character, or description, save religion or partisan politics."
      }
    },
    {
      source_key: "regular_meeting.announcements",
      title: "Announcements",
      slug: "announcements",
      summary: "Dates, reminders, locations, deadlines, volunteer instructions, and other information requiring no decision.",
      category: "business",
      behavior_type: "business_item",
      body: "Announce upcoming Post, County, District, Department, and community events; meeting reminders; deadlines; locations; and volunteer instructions."
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
      ENTRIES.each_with_index do |entry_attributes, index|
        entry = @organization.agenda_item_catalog_entries.find_by(source_key: entry_attributes.fetch(:source_key))
        if entry
          upgrade_untouched_fields(entry, entry_attributes)
          next
        end

        @organization.agenda_item_catalog_entries.create!(
          entry_attributes.except(:body, :legacy).merge(
            position: index + 1,
            active: true,
            source_label: SOURCE_LABEL,
            seeded_at: seeded_at,
            body: entry_attributes.fetch(:body)
          )
        )
      end
    end
  end

  private

  def upgrade_untouched_fields(entry, entry_attributes)
    legacy_attributes = entry_attributes[:legacy]
    return if legacy_attributes.blank? || entry.source_label != SOURCE_LABEL

    updates = legacy_attributes.each_with_object({}) do |(attribute, old_value), result|
      current_value = attribute == :body ? entry.body.to_plain_text : entry.public_send(attribute)
      result[attribute] = entry_attributes.fetch(attribute) if comparable(current_value) == comparable(old_value)
    end
    entry.update!(updates) if updates.any?
  end

  def comparable(value)
    value.to_s.strip.gsub(/\r\n?/, "\n")
  end
end
