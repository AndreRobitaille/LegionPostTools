module EndeavorHistory
  module Manage
    module_function

    def change(endeavor, user:, action:, lock_version:, guidance: nil)
      raise Error, "forbidden" unless user.can?("manage_agendas")
      raise Error, "invalid_action" unless %w[guidance withdraw resume].include?(action)
      endeavor.with_lock do
        raise ActiveRecord::StaleObjectError.new(endeavor, "update") unless endeavor.lock_version == Integer(lock_version.to_s, 10)
        metadata = {}
        case action
        when "guidance"
          entry = endeavor.history_guidances.create!(author: user, body: guidance.to_s.strip, agent_access_token_id: Current.agent_access_token&.id)
          metadata["guidance_id"] = entry.id
        when "withdraw"
          endeavor.history_withdrawn = true
        when "resume"
          endeavor.history_withdrawn = false
        end
        endeavor.history_generation += 1
        endeavor.save!
        endeavor.history_events.create!(actor: user, action: action, metadata: metadata, agent_access_token_id: Current.agent_access_token&.id)
      end
    rescue ArgumentError
      raise Error, "stale_request"
    end
  end
end
