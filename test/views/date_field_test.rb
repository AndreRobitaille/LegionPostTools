require "test_helper"

class DateFieldTest < ActionView::TestCase
  test "renders a text input pre-filled in DD MMM YYYY and a native picker + button" do
    output = render("shared/date_field", name: "position_assignment[starts_on]", value: Date.new(2026, 1, 1))
    frag = Nokogiri::HTML::DocumentFragment.parse(output)
    assert_select frag, "span.datefield[data-controller=?]", "date-field"
    assert_select frag, "input.datefield-input[name=?][value=?]", "position_assignment[starts_on]", "01 JAN 2026"
    assert_select frag, "input.datefield-native[type=date]"
    assert_select frag, "button.datefield-cal"
  end

  test "renders an empty text input when value is nil" do
    output = render("shared/date_field", name: "position_assignment[ends_on]", value: nil)
    frag = Nokogiri::HTML::DocumentFragment.parse(output)
    assert_select frag, "input.datefield-input[name=?][value=?]", "position_assignment[ends_on]", ""
  end
end
