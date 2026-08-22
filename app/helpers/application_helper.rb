module ApplicationHelper
  def agent_access_token_status(token)
    return "Revoked" if token.revoked?
    return "Expired" if token.expired?
    return "Owner disabled" if token.user.disabled_at.present?

    "Active"
  end
end
