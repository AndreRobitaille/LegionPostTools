module NavigationHelper
  def nav_section_for(path)
    return :people if path == "/people" || path.start_with?("/people/", "/admin/people")
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
end
