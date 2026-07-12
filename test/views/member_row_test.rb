require "test_helper"

class MemberRowTest < ActionView::TestCase
  include StatusDisplayHelper

  test "renders name, office, and a status column with the gold edge for officers" do
    output = render("shared/member_row",
      name: "Robert A. Hansen", office: "Commander", path: "/admin/people/1",
      subline: "U.S. Army · Vietnam", membership: true,
      status_tag: membership_status_tag("Active"),
      status_lines: [ "Paid through: 2027", "Sign-in: Yes" ])
    frag = Nokogiri::HTML::DocumentFragment.parse(output)
    assert_select frag, "a.mrow.mrow--office[href=?]", "/admin/people/1"
    assert_select frag, ".mrow-name", "Robert A. Hansen"
    assert_select frag, ".mrow-office", "Commander"
    assert_select frag, ".mrow-status .st--active"
    assert_select frag, ".mrow-status .mrow-kv", text: /Paid through: 2027/
  end

  test "non-officer row has no gold edge and no office label" do
    output = render("shared/member_row",
      name: "Mary E. Kowalski", office: nil, path: "/admin/people/2",
      subline: "U.S. Air Force · Gulf War", membership: false,
      status_tag: nil, status_lines: [])
    frag = Nokogiri::HTML::DocumentFragment.parse(output)
    assert_select frag, "a.mrow", count: 1
    assert_select frag, "a.mrow--office", count: 0
    assert_select frag, ".mrow-office", count: 0
    assert_select frag, ".mrow-status", count: 0
  end
end
