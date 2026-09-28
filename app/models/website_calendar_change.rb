class WebsiteCalendarChange < ApplicationRecord
  belongs_to :organization

  def readonly? = persisted?

  def self.record!(record, action:, details:, actor:)
    token = Current.agent_access_token
    if token && token.user_id == actor&.id
      details = details.merge("delegated_agent" => { token_id: token.id, name: token.name })
    end
    create!(organization_id: record.is_a?(Organization) ? record.id : record.organization_id,
      record_type: record.class.name, record_id: record.id, actor_id: actor&.id,
      action: action, details: details)
  end
end
