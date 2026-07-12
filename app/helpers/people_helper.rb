module PeopleHelper
  def signin_line(person)
    user = person.user
    state = if user.nil? then "No account"
    elsif user.disabled_at.present? then "No"
    else "Yes"
    end
    "Sign-in: #{state}"
  end
end
