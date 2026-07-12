require "test_helper"

class NavigationHelperTest < ActionView::TestCase
  test "nav_section_for maps people paths" do
    assert_equal :people, nav_section_for("/people")
    assert_equal :people, nav_section_for("/people/42")
  end

  test "nav_section_for maps admin paths that are not people" do
    assert_equal :admin, nav_section_for("/admin")
    assert_equal :admin, nav_section_for("/admin/roster_imports/new")
  end

  test "nav_section_for maps settings paths" do
    assert_equal :settings, nav_section_for("/settings/security")
  end

  test "nav_section_for defaults to dashboard" do
    assert_equal :dashboard, nav_section_for("/")
  end

  test "nav_tab_class marks the active section" do
    def self.current_nav_section = :people
    assert_equal "nav-tab nav-tab--active", nav_tab_class(:people)
    assert_equal "nav-tab", nav_tab_class(:settings)
  end
end
