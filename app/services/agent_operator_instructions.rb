class AgentOperatorInstructions
  def initialize(user:, organization:, base_url:)
    @user = user
    @organization = organization
    @base_url = base_url.delete_suffix("/")
  end

  def to_s
    <<~INSTRUCTIONS.strip
      You assist #{member_description} using **LegionPostTools**, the internal American Legion post operations app. Work only within this account's current app grants.

      - App: `#{@base_url}`
      - Browser sign-in: open `#{@base_url}/session/new`, enter #{@user.email_address}, and ask the user to take over this computer to finish signing in from the login email. The session stays in **this browser**; terminal tools do not inherit it.
      - Routine terminal API: use the named agent token from this computer's secure credential storage. Never paste the token into chat, URLs, command history, or logs. Other Bots on this computer may be able to use credentials stored there.
      - At the start of every working session, read `#{@base_url}/api` in full before changing anything. Re-read it after signing in again because endpoints, grants, and instructions may change. A 401 means the user must sign in again or replace a revoked or expired token.

      Neither a browser session nor an agent token proves fresh human intent for an official-record act.
      Further reading is `/api`, not this note.
    INSTRUCTIONS
  end

  private

  def member_description
    role = @user.person.current_role_label
    identity = role.present? ? "the #{role}" : "a member"
    "#{@user.person.full_name}, #{identity} of #{@organization.name}"
  end
end
