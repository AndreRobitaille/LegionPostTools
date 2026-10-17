module ApplicationHelper
  def members_site
    Rails.application.config.x.members_site
  end

  def members_browser_title
    return members_site.name unless authenticated?

    content_for(:title).presence || members_site.name
  end

  def agent_access_token_status(token)
    return "Revoked" if token.revoked?
    return "Expired" if token.expired?
    return "Owner disabled" if token.user.disabled_at.present?

    "Active"
  end
end
