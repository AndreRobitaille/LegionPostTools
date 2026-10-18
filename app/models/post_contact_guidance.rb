# Member-facing explanations of standard offices, not authorization policy.
# Source and the Post's contact-routing decision are recorded in docs/CONTACT_THE_POST.md.
module PostContactGuidance
  PRIMARY_CONTACTS = {
    "Commander" => {
      heading: "Post questions and getting involved",
      responsibility: "Leads the Post and helps members with Post business, concerns, and ways to get involved.",
      examples: [ "I have a question or concern about the Post.", "I'd like to help with a Post activity." ]
    },
    "Service Officer" => {
      heading: "Veteran benefits and support",
      responsibility: "Connects veterans and their families with benefits guidance and local support.",
      examples: [ "Where can I get help with a VA claim?", "My family needs support. Where can we turn?" ]
    }
  }.freeze

  OTHER_OFFICES = {
    "1st Vice Commander" => {
      responsibility: "Handles membership and renewals.",
      examples: [ "Renewing membership", "Returning to the Post" ]
    },
    "2nd Vice Commander" => {
      responsibility: "Helps organize Post activities and social gatherings.",
      examples: [ "Helping at events", "Suggesting an activity" ]
    },
    "Adjutant" => {
      responsibility: "Keeps the Post's records and handles official messages.",
      examples: [ "Updating contact details", "Finding meeting minutes" ]
    },
    "Finance Officer" => {
      responsibility: "Manages the Post's finances and financial records.",
      examples: [ "Payment receipts", "Expense reimbursements" ]
    },
    "Chaplain" => {
      responsibility: "Offers spiritual support and comfort to members and families.",
      examples: [ "A member is ill", "A death in the family" ]
    },
    "Sergeant-at-Arms" => {
      responsibility: "Helps meetings and ceremonies run smoothly and welcomes members.",
      examples: [ "Your first meeting", "Flag ceremonies" ]
    },
    "Historian" => {
      responsibility: "Preserves the Post's history.",
      examples: [ "Sharing old photos", "Past Post events" ]
    },
    "Judge Advocate" => {
      responsibility: "Advises the Post on its rules and meeting procedures.",
      examples: [ "Understanding a Post rule", "How voting works" ]
    },
    "Assistant Chaplain" => {
      responsibility: "Assists the Chaplain in supporting members and families.",
      examples: [ "A member is ill", "A death in the family" ]
    }
  }.freeze
end
