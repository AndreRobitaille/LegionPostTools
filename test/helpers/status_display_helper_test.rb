require "test_helper"

class StatusDisplayHelperTest < ActionView::TestCase
  test "active status renders the active class and label" do
    frag = Nokogiri::HTML::DocumentFragment.parse(membership_status_tag("Active"))
    assert_select frag, "span.st.st--active", text: /Active/
    assert_select frag, "span.st--active .st-dot"
  end

  test "expired status renders the expired class" do
    frag = Nokogiri::HTML::DocumentFragment.parse(membership_status_tag("Expired"))
    assert_select frag, "span.st.st--expired", text: /Expired/
  end

  test "unknown status renders the muted variant with its own label" do
    frag = Nokogiri::HTML::DocumentFragment.parse(membership_status_tag("Deceased"))
    assert_select frag, "span.st.st--other", text: /Deceased/
  end

  test "blank status renders nothing" do
    assert_equal "", membership_status_tag(nil)
    assert_equal "", membership_status_tag("")
  end

  test "status matching is case insensitive" do
    html = membership_status_tag("ACTIVE")
    assert_includes html, "st--active"
  end

  test "status text is escaped" do
    html = membership_status_tag("<script>")
    assert_includes html, "&lt;script&gt;"
  end

  test "dated agenda draft status renders the draft variant" do
    frag = Nokogiri::HTML::DocumentFragment.parse(dated_agenda_status_tag("draft"))
    assert_select frag, "span.st.st--draft", text: /Draft/
    assert_select frag, "span.st--draft .st-dot"
  end

  test "dated agenda approved status renders the approved variant" do
    frag = Nokogiri::HTML::DocumentFragment.parse(dated_agenda_status_tag("approved"))
    assert_select frag, "span.st.st--approved", text: /Approved/
  end

  test "dated agenda published status renders the published variant" do
    frag = Nokogiri::HTML::DocumentFragment.parse(dated_agenda_status_tag("published"))
    assert_select frag, "span.st.st--published", text: /Published/
  end

  test "dated agenda unknown status falls back to the muted variant with a titleized label" do
    frag = Nokogiri::HTML::DocumentFragment.parse(dated_agenda_status_tag("archived"))
    assert_select frag, "span.st.st--other", text: /Archived/
  end
end
