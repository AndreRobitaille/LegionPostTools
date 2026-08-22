module NavigationHelper
  def nav_section_for(path)
    return :meetings if path == "/dated_agendas" || path.start_with?("/dated_agendas/")
    return :people if path == "/people" || path.start_with?("/people/")
    return :tracked_items if path == "/tracked_items" || path.start_with?("/tracked_items/")
    return :admin if path.start_with?("/admin")
    return :settings if path.start_with?("/settings")

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
end
