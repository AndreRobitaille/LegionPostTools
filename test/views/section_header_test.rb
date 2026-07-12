require "test_helper"

class SectionHeaderTest < ActionView::TestCase
  test "renders the label and a rule" do
    output = render("shared/section_header", label: "Post Officers")
    frag = Nokogiri::HTML::DocumentFragment.parse(output)
    assert_select frag, ".sec-head .sec-head-label", "Post Officers"
    assert_select frag, ".sec-head .sec-head-rule"
  end
end
