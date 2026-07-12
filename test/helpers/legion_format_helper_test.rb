require "test_helper"

class LegionFormatHelperTest < ActionView::TestCase
  test "legion_date formats a date as DD MMM YYYY uppercase" do
    assert_equal "24 JUN 2026", legion_date(Date.new(2026, 6, 24))
    assert_equal "01 JAN 1995", legion_date(Date.new(1995, 1, 1))
  end

  test "legion_date returns empty string for nil" do
    assert_equal "", legion_date(nil)
  end

  test "legion_time formats 24-hour HH:MM" do
    assert_equal "14:32", legion_time(Time.utc(2026, 6, 24, 14, 32))
    assert_equal "09:05", legion_time(Time.utc(2026, 6, 24, 9, 5))
  end

  test "legion_datetime joins date and time with a diamond dot" do
    assert_equal "24 JUN 2026 · 14:32", legion_datetime(Time.utc(2026, 6, 24, 14, 32))
    assert_equal "", legion_datetime(nil)
  end

  test "parse_legion_date parses DD MMM YYYY case-insensitively" do
    assert_equal Date.new(1995, 1, 1), parse_legion_date("01 JAN 1995")
    assert_equal Date.new(2026, 6, 24), parse_legion_date("  24 jun 2026 ")
  end

  test "parse_legion_date returns nil for blank or invalid input" do
    assert_nil parse_legion_date("")
    assert_nil parse_legion_date(nil)
    assert_nil parse_legion_date("not a date")
    assert_nil parse_legion_date("32 JAN 1995")
  end
end
