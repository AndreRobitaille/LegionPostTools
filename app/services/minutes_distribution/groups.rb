module MinutesDistribution::Groups
  module_function

  def verify!(settings, client)
    unless settings&.groups_configured?
      raise Loops::Client::RequestError, "Configure distinct Post members and Minutes recipients groups before using Loops."
    end
    lists = client.mailing_lists.index_by { |list| list.fetch("id") }
    [ settings.post_members_list_id, settings.minutes_recipients_list_id ].each do |id|
      unless lists[id] && lists[id]["isPublic"] == false
        raise Loops::Client::RequestError, "A configured private email group is missing or public in Loops."
      end
    end
  end
end
