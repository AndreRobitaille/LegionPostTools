class AddContactGuidanceToPositionTitles < ActiveRecord::Migration[8.1]
  # Keep the approved initial copy here so later default changes cannot alter this migration.
  INITIAL_GUIDANCE = {
    "Commander" => {
      responsibility: "Leads the Post's work and coordinates its officers and committees.",
      examples: [ "You have a concern about a Post decision or how you were treated.", "You want to raise an issue at a Post meeting." ]
    },
    "Service Officer" => {
      responsibility: "Helps veterans and families understand benefits and find help with claims and other needs.",
      examples: [ "You need help getting started with a VA claim.", "You or your family are struggling and need help finding support." ]
    },
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

  def up
    add_column :position_titles, :contact_description, :text
    add_column :position_titles, :contact_examples, :jsonb, null: false, default: []
    add_check_constraint :position_titles, "jsonb_typeof(contact_examples) = 'array'", name: "position_contact_examples_array"
    backfill_contact_guidance
  end

  def down
    remove_check_constraint :position_titles, name: "position_contact_examples_array"
    remove_column :position_titles, :contact_examples
    remove_column :position_titles, :contact_description
  end

  private

  def backfill_contact_guidance
    INITIAL_GUIDANCE.each do |name, guidance|
      execute <<~SQL
        UPDATE position_titles
        SET contact_description = #{connection.quote(guidance.fetch(:responsibility))},
            contact_examples = #{connection.quote(guidance.fetch(:examples).to_json)}::jsonb
        WHERE name = #{connection.quote(name)}
      SQL
    end
    execute <<~SQL
      UPDATE position_titles
      SET contact_description = 'Assists the ' || btrim(substring(name FROM 11)) || '.',
          contact_examples = '[]'::jsonb
      WHERE name LIKE 'Assistant %' AND btrim(substring(name FROM 11)) <> ''
    SQL
  end
end
