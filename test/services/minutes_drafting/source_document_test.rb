require "test_helper"

class MinutesDrafting::SourceDocumentTest < ActiveSupport::TestCase
  test "preserves normal transcript lines with stable numbering" do
    document = MinutesDrafting::SourceDocument.new("Commander: Call to order.\nAdjutant: Roll call.")

    assert_equal [ "Commander: Call to order.", "Adjutant: Roll call." ], document.lines
    assert_equal "L0001 Commander: Call to order.\nL0002 Adjutant: Roll call.", document.rendered
    assert_equal "L0002 Adjutant: Roll call.", document.excerpt(2, 2)
  end

  test "turns a punctuation-only single-line transcript into reviewable source lines" do
    transcript = Array.new(20) { |index| "Speaker discussed agenda matter #{index + 1}." }.join(" ")
    document = MinutesDrafting::SourceDocument.new(transcript)

    assert_operator document.lines.length, :>, 1
    assert document.lines.all? { |line| line.length <= MinutesDrafting::SourceDocument::MAX_LINE_LENGTH }
    assert_match(/L0001 Speaker discussed agenda matter 1/, document.rendered)
  end

  test "does not lose content from an oversized passage without spaces" do
    transcript = "A" * (MinutesDrafting::SourceDocument::MAX_LINE_LENGTH + 50)
    document = MinutesDrafting::SourceDocument.new(transcript)

    assert_equal transcript, document.lines.join
    assert_equal [ MinutesDrafting::SourceDocument::MAX_LINE_LENGTH, 50 ], document.lines.map(&:length)
  end
end
