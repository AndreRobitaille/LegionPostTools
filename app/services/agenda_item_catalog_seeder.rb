class AgendaItemCatalogSeeder
  SOURCE_LABEL = "Officer's Guide regular meeting seed"

  ENTRIES = [
    {
      source_key: "regular_meeting.opening_ceremony",
      title: "Opening Ceremony",
      slug: "opening-ceremony",
      summary: "Begins the regular meeting with colors, prayer, POW/MIA recognition, pledge, and preamble.",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      body: "The commander announces that the meeting is about to open. Officers take their stations. The sergeant-at-arms closes the doors of the meeting hall. The commander gives three raps of the gavel and all present stand at attention. The color bearers advance the colors. The commander commands: Hand salute. After the colors are posted, the commander commands: Two. The chaplain offers prayer. The meeting continues with the POW/MIA Empty Chair ceremony, Pledge of Allegiance, and American Legion Preamble."
    },
    {
      source_key: "regular_meeting.opening_prayer",
      title: "Opening Prayer",
      slug: "opening-prayer",
      summary: "Suggested nonsectarian opening prayer from the regular meeting ceremony.",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      body: "Almighty God, Father of all mankind and Judge over nations, we pray Thee to guide our work in this meeting and in all our days. Send Thy peace to our nation and to all nations. Hasten the fulfillment of Thy promise of peace that shall have no end.\n\nWe pray for those who serve the people and guard the public welfare, that by Thy blessing they may be enabled to discharge their duties honestly and well. We pray that by Thy help they may observe the strictest justice, keep alight the fires of freedom, strive earnestly for the spirit of democracy, and preserve untarnished our loyalty to our country and to Thee. Finally, O God of mercy, we ask Thy blessing and comfort for those who are suffering mental and physical disability. Cheer them and bring them the blessings of health and happiness. Amen."
    },
    {
      source_key: "regular_meeting.pow_mia_empty_chair",
      title: "POW/MIA Empty Chair",
      slug: "pow-mia-empty-chair",
      summary: "Recognition of American POW/MIAs still unaccounted for.",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      body: "A POW/MIA empty chair is placed at all official meetings of The American Legion as a physical symbol of many American POW/MIAs still unaccounted for from all wars and conflicts involving the United States of America. This is a reminder for all of us to spare no effort to secure the release of any American prisoners from captivity, the repatriation of the remains of those who died bravely in defense of liberty, and a full accounting of those missing. Let us rededicate ourselves to this vital endeavor!\n\nPlace the POW/MIA flag on the empty chair."
    },
    {
      source_key: "regular_meeting.pledge_of_allegiance",
      title: "Pledge of Allegiance",
      slug: "pledge-of-allegiance",
      summary: "The Pledge of Allegiance recited during the opening ceremony.",
      category: "ceremony",
      behavior_type: "reading_recitation",
      body: "I pledge allegiance to the Flag of the United States of America and to the Republic for which it stands, one Nation under God, indivisible, with liberty and justice for all."
    },
    {
      source_key: "regular_meeting.preamble",
      title: "American Legion Preamble",
      slug: "american-legion-preamble",
      summary: "The Preamble to the Constitution of The American Legion.",
      category: "ceremony",
      behavior_type: "reading_recitation",
      body: "For God and Country, we associate ourselves together for the following purposes:\n\nTo uphold and defend the Constitution of the United States of America;\nTo maintain law and order;\nTo foster and perpetuate a one hundred percent Americanism;\nTo preserve the memories and incidents of our associations in all wars;\nTo inculcate a sense of individual obligation to the community, state and nation;\nTo combat the autocracy of both the classes and the masses;\nTo make right the master of might;\nTo promote peace and goodwill on earth;\nTo safeguard and transmit to posterity the principles of justice, freedom and democracy;\nTo consecrate and sanctify our comradeship by our devotion to mutual helpfulness."
    },
    { source_key: "regular_meeting.closing_ceremony", title: "Closing Ceremony", slug: "closing-ceremony", summary: "Closes the regular meeting with memorial service, POW/MIA flag recovery, colors, and adjournment.", category: "ceremony", behavior_type: "scripted_ceremony", body: "The commander asks: Is there any further business to come before the meeting? If not, the chaplain will lead us in memorial service.\n\nThe membership rises, uncovers, and stands in silence. The chaplain offers the memorial prayer. The commander directs the sergeant-at-arms to recover the POW/MIA flag. The commander reminds members that service to community, state, and nation is a main objective of The American Legion. The color bearers retire the flag of our country. The commander declares the meeting adjourned with one rap of the gavel." },
    { source_key: "regular_meeting.roll_call_quorum", title: "Roll Call and Quorum", slug: "roll-call-and-quorum", summary: "Determine whether enough members are present to conduct authorized business.", category: "administration", behavior_type: "business_item", body: "Roll call to determine if a quorum is present before conducting official business." },
    { source_key: "regular_meeting.previous_minutes", title: "Previous Meeting Minutes", slug: "previous-meeting-minutes", summary: "Read, correct, and approve the previous meeting minutes.", category: "administration", behavior_type: "motion_vote_item", body: "The adjutant reads the minutes of the previous meeting. The chair asks for corrections. If there are no corrections, the minutes stand approved as read; if corrected, they stand approved as corrected." },
    { source_key: "regular_meeting.introductions", title: "Introduction of Guests and Prospective/New Members", slug: "introduction-of-guests-and-prospective-new-members", summary: "Welcome guests, prospective members, and new members.", category: "membership", behavior_type: "business_item", body: "Introduce guests, prospective members, and new members so they are recognized and welcomed by the post." },
    { source_key: "regular_meeting.committee_reports", title: "Committee Reports", slug: "committee-reports", summary: "Reports from standing or special committees scheduled to report.", category: "reports", behavior_type: "section_heading", body: "The agenda should list committees scheduled to report. Confirm that a chairperson is ready before placing the report on the agenda." },
    { source_key: "regular_meeting.balloting_on_applications", title: "Balloting on Applications", slug: "balloting-on-applications", summary: "Act on membership applications when required by post procedure.", category: "membership", behavior_type: "motion_vote_item", body: "Ballot on applications for membership according to the post constitution, by-laws, and applicable American Legion procedures." },
    { source_key: "regular_meeting.sick_call_relief_employment", title: "Sick Call, Relief, and Employment", slug: "sick-call-relief-and-employment", summary: "Share member welfare, relief, employment, or assistance needs.", category: "business", behavior_type: "business_item", body: "Use this time for sick call, relief, employment, and other member welfare matters appropriate for the meeting." },
    { source_key: "regular_meeting.service_officer_report", title: "Post Service Officer Report", slug: "post-service-officer-report", summary: "Standard report from the post service officer.", category: "reports", behavior_type: "report_slot", body: "The post service officer reports on veteran service matters, benefits awareness, claims support, and related assistance." },
    { source_key: "regular_meeting.unfinished_old_business", title: "Unfinished / Old Business", slug: "unfinished-old-business", summary: "Business carried over from earlier meetings.", category: "business", behavior_type: "section_heading", body: "Bring forward business postponed from previous meetings or matters introduced earlier where action was not completed." },
    { source_key: "regular_meeting.new_business_correspondence", title: "New Business and Correspondence", slug: "new-business-and-correspondence", summary: "New business, correspondence, and motions for post action.", category: "business", behavior_type: "section_heading", body: "Introduce new business, communications, correspondence, and motions calling for action by the post." },
    { source_key: "regular_meeting.memorial_departed_member", title: "Memorial to a Departed Post Member", slug: "memorial-to-a-departed-post-member", summary: "Memorial recognition for a departed post member when needed.", category: "memorial", behavior_type: "scripted_ceremony", body: "Use this item when the post needs to recognize a departed member during the regular meeting. The post may use an appropriate memorial, charter-draping, or Post Everlasting ceremony when applicable." },
    { source_key: "regular_meeting.good_of_legion", title: "Good of The American Legion", slug: "good-of-the-american-legion", summary: "Suggestions and remarks for the good of The American Legion.", category: "business", behavior_type: "business_item", body: "Members may make suggestions of any kind, character, or description, save religion or partisan politics." }
  ].freeze

  def self.seed_for!(organization)
    new(organization).seed!
  end

  def initialize(organization)
    @organization = organization
  end

  def seed!
    ENTRIES.each_with_index do |entry_attributes, index|
      next if @organization.agenda_item_catalog_entries.exists?(source_key: entry_attributes.fetch(:source_key))

      @organization.agenda_item_catalog_entries.create!(
        entry_attributes.except(:body).merge(
          position: index + 1,
          active: true,
          source_label: SOURCE_LABEL,
          seeded_at: Time.current,
          body: entry_attributes.fetch(:body)
        )
      )
    end
  end
end
