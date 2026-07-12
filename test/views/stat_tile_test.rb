require "test_helper"

class StatTileTest < ActionView::TestCase
  test "renders count, label, and variant class" do
    output = render("shared/stat_tile", count: 12, label: "Created", variant: "created")
    frag = Nokogiri::HTML::DocumentFragment.parse(output)
    assert_select frag, ".stat-tile.stat-tile--created .stat-n", "12"
    assert_select frag, ".stat-tile--created .stat-t", "Created"
  end
end
