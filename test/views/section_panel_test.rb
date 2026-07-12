require "test_helper"

class SectionPanelTest < ActionView::TestCase
  test "renders the label, a body, and optional provenance" do
    output = render(layout: "shared/section_panel", locals: { label: "Roster Record", provenance: "imported 24 JUN 2026" }) { "PANEL BODY" }
    assert_select_in output, ".card .card-head .card-head-label", "Roster Record"
    assert_select_in output, ".card .card-head .card-head-prov", "imported 24 JUN 2026"
    assert_select_in output, ".card .card-body", text: /PANEL BODY/
  end

  test "omits provenance when not given" do
    output = render(layout: "shared/section_panel", locals: { label: "Login Account" }) { "X" }
    assert_select_in output, ".card-head-prov", count: 0
  end

  private

  def assert_select_in(html, *args, &block)
    assert_select(Nokogiri::HTML::DocumentFragment.parse(html), *args, &block)
  end
end
