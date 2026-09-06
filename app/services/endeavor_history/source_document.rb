module EndeavorHistory
  class SourceDocument
    VERSION = "1".freeze
    BLOCKS = "p, li, div, h1, h2, h3, h4, blockquote, tr".freeze
    attr_reader :revision

    def initialize(revision)
      @revision = revision
    end

    def items
      @items ||= revision.payload.fetch("sections").flat_map do |section|
        section.fetch("items").map do |item|
          key = item.fetch("record_key")
          prefix = "r#{revision.id}:#{key}"
          units = paragraphs(item["body_html"]).each_with_index.map do |text, index|
            { "id" => "#{prefix}:body:#{index}", "kind" => "body", "text" => text }
          end
          item.fetch("outcomes").each_with_index do |outcome, index|
            units << { "id" => "#{prefix}:outcome:#{index}", "kind" => "outcome", "text" => outcome.fetch("text"), "outcome" => outcome }
          end
          { "key" => key, "title" => item.fetch("title"), "section" => section.fetch("title"),
            "primary_endeavor_id" => item["endeavor_id"], "units" => units }
        end
      end
    end

    def units = items.flat_map { |item| item.fetch("units") }

    def payload
      { "revision_id" => revision.id, "sha256" => revision.sha256,
        "meeting_id" => revision.meeting_minutes.meeting_id, "date" => revision.payload.fetch("starts_at"),
        "meeting_body" => revision.payload.fetch("meeting_body_name"), "items" => items }
    end

    private

    def paragraphs(html)
      fragment = Nokogiri::HTML.fragment(html.to_s)
      fragment.css("script, style").remove
      fragment.css("br").each { |node| node.replace("\n") }
      fragment.css(BLOCKS).each { |node| node.add_next_sibling(Nokogiri::XML::Text.new("\n", fragment.document)) }
      fragment.text.lines.map(&:squish).reject(&:empty?).flat_map { |line| line.scan(/.{1,2000}(?:\s+|\z)|.{1,2000}/).map(&:strip) }
    end
  end
end
