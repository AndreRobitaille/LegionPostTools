require "test_helper"

class MinutesDistribution::ContentTest < ActiveSupport::TestCase
  test "visible changes and order change the mailing digest without AI" do
    base = { "title" => "Monthly meeting", "attendance" => [ { "office_name" => "Commander", "status" => "present" } ],
      "sections" => [ { "title" => "Finance", "items" => [ { "body_html" => "<p>Balance: $100.</p>",
        "outcomes" => [ { "vote_summary" => "10 to 1" } ] } ] } ] }
    original = digest(base)
    [
      ->(copy) { copy["title"] = "PEC meeting" },
      ->(copy) { copy["attendance"][0]["status"] = "absent" },
      ->(copy) { copy["sections"][0]["title"] = "Treasurer" },
      ->(copy) { copy["sections"][0]["items"][0]["body_html"] = "<p>Balance: $101.</p>" },
      ->(copy) { copy["sections"][0]["items"][0]["outcomes"][0]["vote_summary"] = "11 to 1" }
    ].each do |change|
      copy = base.deep_dup
      change.call(copy)
      assert_not_equal original, digest(copy)
    end
    assert_not_equal digest({ "sections" => [ { "title" => "A" }, { "title" => "B" } ] }),
      digest({ "sections" => [ { "title" => "B" }, { "title" => "A" } ] })
  end

  test "internal links editor wrappers and insignificant whitespace do not cause corrected mail" do
    a = { "sections" => [ { "position" => 1, "items" => [ { "record_key" => "a", "endeavor_id" => 1,
      "source_dated_agenda_item_id" => 2, "body_html" => '<div class="trix-content"><p>Balance:  $100.</p></div>' } ] } ] }
    b = { "sections" => [ { "position" => 3, "items" => [ { "record_key" => "b", "endeavor_id" => 4,
      "source_dated_agenda_item_id" => 5, "body_html" => "<p>Balance: $100.</p>" } ] } ] }
    assert_equal digest(a), digest(b)
    assert_not_equal digest({ "body_html" => "<p>A</p><p>B</p>" }), digest({ "body_html" => "<p>A B</p>" })
  end

  test "printed list type and omitted-image description remain meaningful content" do
    assert_not_equal digest({ "body_html" => "<ul><li>Report</li></ul>" }), digest({ "body_html" => "<ol><li>Report</li></ol>" })
    assert_not_equal digest({ "body_html" => '<img src="/a" alt="Old chart">' }), digest({ "body_html" => '<img src="/b" alt="Corrected chart">' })
    assert_equal digest({ "body_html" => '<img src="/a" alt="Chart">' }), digest({ "body_html" => '<img src="/b" alt="Chart">' })
  end

  private
  def digest(payload) = MinutesDistribution::Content.digest(payload)
end
