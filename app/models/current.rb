class Current < ActiveSupport::CurrentAttributes
  attribute :session, :agent_access_token
end
