# Initial copy for new positions. Pages and feeds read the saved PositionTitle fields.
# Source pages and the Post's contact-routing decision are in docs/CONTACT_THE_POST.md.
module PostContactGuidance
  PRIMARY_CONTACTS = {
    "Commander" => {
      responsibility: "Leads the Post's work and coordinates its officers and committees.",
      examples: [ "You have a concern about a Post decision or how you were treated.", "You want to raise an issue at a Post meeting." ]
    },
    "Service Officer" => {
      responsibility: "Helps veterans and families understand benefits and find help with claims and other needs.",
      examples: [ "You need help getting started with a VA claim.", "You or your family are struggling and need help finding support." ]
    }
  }.freeze

  PRIMARY_OFFICES = PRIMARY_CONTACTS.keys.freeze

  OTHER_OFFICES = {
    "1st Vice Commander" => {
      responsibility: "Leads member recruitment and retention, and fills in for the Commander.",
      examples: [ "You need help renewing your membership.", "You know a veteran who would like to join." ]
    },
    "2nd Vice Commander" => {
      responsibility: "Coordinates the Post's fundraising and events.",
      examples: [ "You have a question about an upcoming event or fundraiser.", "You want to suggest an event or help with a fundraiser." ]
    },
    "Adjutant" => {
      responsibility: "Manages Post records, meeting minutes and member communications.",
      examples: [ "Your address or contact information has changed.", "You need a replacement membership card or a copy of meeting minutes." ]
    },
    "Finance Officer" => {
      responsibility: "Oversees Post funds, financial reports and the budget.",
      examples: [ "You need to submit a receipt for a Post expense.", "You have a question about the Post's financial report." ]
    },
    "Chaplain" => {
      responsibility: "Offers spiritual guidance and personal support to members and families, including during illness or loss.",
      examples: [ "You would like prayer, encouragement or someone to talk to.", "You know a member who is ill or grieving and would appreciate a card, call or visit." ]
    },
    "Sergeant-at-Arms" => {
      responsibility: "Prepares meetings, welcomes members and coordinates flag ceremonies.",
      examples: [ "You're coming to a meeting and would like help getting settled.", "You have a question about displaying or retiring a flag." ]
    },
    "Historian" => {
      responsibility: "Preserves the Post's history and archives.",
      examples: [ "You have Post photos or memorabilia to share.", "You want to learn about the Post's history or a past member's involvement." ]
    },
    "Judge Advocate" => {
      responsibility: "Advises on Post bylaws, elections and meeting procedures.",
      examples: [ "You want to understand a Post bylaw or election rule.", "You have a question about how to make a motion or how voting works." ]
    }
  }.freeze

  def self.defaults_for(office)
    if office.start_with?("Assistant ") && (primary_office = office.delete_prefix("Assistant ").strip).present?
      { responsibility: "Assists the #{primary_office}.", examples: [] }
    else
      PRIMARY_CONTACTS[office] || OTHER_OFFICES[office]
    end
  end
end
