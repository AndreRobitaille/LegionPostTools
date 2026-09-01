module NavigationHelper
  # One source of truth for the primary destinations. The tab strip and the
  # account menu both render this list, so adding a destination in one place
  # cannot leave the other behind.
  def primary_destinations
    [
      { section: :dashboard, label: "Dashboard", path: root_path },
      { section: :meetings, label: "Meetings", path: meetings_path },
      { section: :endeavors, label: "Endeavors", path: endeavors_path },
      { section: :people, label: "People", path: people_path }
    ]
  end

  # Admin is capability-gated and rendered apart from the others, so it is
  # returned separately rather than folded into the list above.
  def admin_destination
    return nil unless current_user.can_any?(*User::ADMIN_AREA_CAPABILITIES)

    { section: :admin, label: admin_navigation_label, path: admin_root_path }
  end

  def admin_area_name
    current_user.can?("manage_settings") ? "Administration" : "Officer tools"
  end

  def admin_navigation_label
    current_user.can?("manage_settings") ? "Admin" : "Officer tools"
  end

  def nav_section_for(path)
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
