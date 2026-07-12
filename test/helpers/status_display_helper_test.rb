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
end
