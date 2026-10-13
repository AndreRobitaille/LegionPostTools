module NavigationHelper
  # One source of truth for the primary destinations. The tab strip and the
  # account menu both render this list, so adding a destination in one place
  # cannot leave the other behind.
  def primary_destinations
    [
      { section: :dashboard, label: "Dashboard", path: root_path },
      { section: :calendar, label: "Calendar", path: calendar_path },
      { section: :meetings, label: "Meetings", path: meetings_path },
      { section: :endeavors, label: "Endeavors", path: endeavors_path },
      { section: :people, label: "People", path: people_path }
    ]
  end

  def work_menu_groups
    personal = []
    if current_user.mobile_buddy_checks_access? || current_user.buddy_check_coordination_access?
      personal << { section: :buddy_checks, label: "Buddy Checks", path: buddy_checks_root_path }
    end
    if current_user.membership_workspace_access? && !current_user.full_membership_access?
      personal << { section: :membership, label: "Your assigned calls", path: membership_follow_up_path }
    end
    groups = []
    groups << { key: :personal, label: "Your work", destinations: personal } if personal.any?
    if current_user.officer_workspace_access?
      groups << { key: :officer, label: "Post duties", destinations: [
        { section: :officer_tools, label: "Officer tools", path: officer_tools_path }
      ] }
    end
    if current_user.can?("manage_settings")
      groups << { key: :administration, label: "Application settings", destinations: [
        { section: :admin, label: "Administration", path: admin_root_path }
      ] }
    end
    groups
  end

  def admin_area_name
    "Administration"
  end

  def workspace_home_path
    current_nav_section == :officer_tools ? officer_tools_path : admin_root_path
  end

  def workspace_home_label
    current_nav_section == :officer_tools ? "Officer tools" : "Administration"
  end

  def nav_section_for(path)
    return :buddy_checks if path == "/buddy-checks" || path.start_with?("/buddy-checks/")
    return :buddy_checks if path.start_with?("/membership/buddy-attendance")
    return :profile if path.start_with?("/mobile/sessions")
    return :officer_tools if path == "/officer-tools"
    if path == "/membership" || path.start_with?("/membership/")
      return current_user&.full_membership_access? ? :officer_tools : :membership
    end
    operational = %w[meetings meeting_types agenda_item_catalog_entries dated_agendas meeting_minutes minutes_draft_runs transcript_imports endeavors endeavor_history_runs website_publications]
    return :officer_tools if operational.any? { |part| path == "/admin/#{part}" || path.start_with?("/admin/#{part}/") }
    return :officer_tools if path.start_with?("/admin/jobs") && !current_user&.can?("manage_settings")
    return :calendar if path == "/calendar" || path.start_with?("/calendar/") || path == "/calendar_events" || path.start_with?("/calendar_events/")
    return :meetings if path == "/meetings" || path.start_with?("/meetings/") || path == "/dated_agendas" || path.start_with?("/dated_agendas/")
    return :people if path == "/people" || path.start_with?("/people/")
    return :endeavors if path == "/endeavors" || path.start_with?("/endeavors/")
    return :admin if path.start_with?("/admin")
    # Profile has no tab of its own; naming it stops the Dashboard tab from
    # falsely highlighting while you are on it.
    return :profile if path.start_with?("/profile")

    :dashboard
  end

  def current_nav_section
    if request.path.start_with?("/membership/") && (@buddy_task || (defined?(@drive) && @drive&.purpose == "buddy_check"))
      return :buddy_checks
    end
    nav_section_for(request.path)
  end

  def nav_tab_class(section)
    section == current_nav_section ? "nav-tab nav-tab--active" : "nav-tab"
  end

  def nav_tab_attributes(section, extra_class: nil)
    {
      class: [ nav_tab_class(section), extra_class ].compact.join(" "),
      aria: section == current_nav_section ? { current: "page" } : {}
    }
  end

  # Same active marking as the tab strip, for the destinations inside the menu.
  def menu_link_attributes(section)
    active = section == current_nav_section
    {
      class: [ "app-menu-link", ("app-menu-link--active" if active) ].compact.join(" "),
      aria: active ? { current: "page" } : {}
    }
  end
end
