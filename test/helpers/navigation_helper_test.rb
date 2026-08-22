require "test_helper"

class NavigationHelperTest < ActionView::TestCase
  test "nav_section_for maps member meeting paths" do
    assert_equal :meetings, nav_section_for("/dated_agendas")
    assert_equal :meetings, nav_section_for("/dated_agendas/42")
  end

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

  test "nav_tab_attributes marks only the active link as current" do
    def self.current_nav_section = :meetings

    assert_equal({ class: "nav-tab nav-tab--active", aria: { current: "page" } }, nav_tab_attributes(:meetings))
    assert_equal({ class: "nav-tab", aria: {} }, nav_tab_attributes(:people))
    assert_equal "nav-tab nav-tab--active nav-tab--admin", nav_tab_attributes(:meetings, extra_class: "nav-tab--admin")[:class]
  end
end
