module PeopleHelper
  def signin_line(person)
    user = person.user
    state = if user.nil? then "No account"
    elsif user.disabled_at.present? then "No — #{disabled_signin_reason(user)}"
    else "Yes"
    end
    "Sign-in: #{state}"
  end

  def disabled_signin_reason(user)
    case user.disabled_reason
    when "manual"
      "disabled by an administrator"
    when "roster_removed"
      "not on the latest National roster"
    when "roster_status"
      "National roster status is #{user.disabled_reason_detail.to_s.titleize.presence || "not eligible"}"
    else
      "reason not recorded"
    end
  end

  def disabled_signin_reason_sentence(user)
    disabled_signin_reason(user).sub(/\A[a-z]/) { |letter| letter.upcase }
  end

  def login_email_submit_label(user)
    return "Save email and enable sign-in" if user.roster_access_should_enable?
    return "Save email and enable sign-in" unless user.roster_managed?

    "Save login email"
  end
end
