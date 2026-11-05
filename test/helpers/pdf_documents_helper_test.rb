require "test_helper"

class PdfDocumentsHelperTest < ActionView::TestCase
  include PdfDocumentsHelper

  test "snapshot and Action Text render safe rich text without altering source" do
    source = "<p>Keep <strong>this report</strong>.</p><ul><li>First item</li></ul><script>alert(1)</script>" \
      '<a href="java&#x73;cript:alert(1)" onclick="alert(1)">Link</a><img src="/sample.png" onerror="alert(1)">' \
      '<noscript><p title="</noscript><img src=x onerror=alert(1)>">Example</p></noscript>'
    original = source.dup
    rich_text = ActionText::RichText.new(body: source)
    [ source, rich_text ].each do |input|
      html = document_rich_text(input)
      parsed = Nokogiri::HTML5.fragment(html)
      assert_equal "this report", parsed.at_css("strong").text
      assert_equal "First item", parsed.at_css("ul li").text
      assert_empty parsed.css("script, noscript, [onclick], [onerror]")
      assert_empty parsed.css("a[href]").select { |node| node["href"].match?(/javascript:/i) }
    end
    assert_equal original, source
  end
end
