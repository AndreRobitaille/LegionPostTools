module MinutesDistribution::Content
  VERSION = 1
  INTERNAL_KEYS = %w[record_key endeavor_id source_dated_agenda_item_id behavior_type position].freeze
  BLOCKS = %w[p div br li ul ol h1 h2 h3 h4 blockquote tr td th hr].freeze
  module_function

  def digest(payload)
    Digest::SHA256.hexdigest(JSON.generate([ VERSION, project(payload) ]))
  end

  def project(value)
    case value
    when Hash
      value.except(*INTERNAL_KEYS).sort.to_h.each_with_object({}) do |(key, item), result|
        result[key] = key.in?(%w[body_html agenda_body_html]) ? rich_text(item) : project(item)
      end
    when Array then value.map { |item| project(item) }
    when String then value.gsub(/[[:space:]]+/, " ").strip
    else value
    end
  end

  def rich_text(html)
    fragment = Rails::HTML5::SafeListSanitizer.new.sanitize(html.to_s)
    document = Nokogiri::HTML5.fragment(fragment)
    document.css("img, picture, video, audio, embed, object, iframe").each do |media|
      kind = media.name.in?(%w[img picture]) ? "Image" : "Media"
      marker = Nokogiri::XML::Text.new([ "#{kind} omitted from PDF", media["alt"].presence ].compact.join(": "), document)
      media.replace(marker)
    end
    document.css(".trix-content, .lexxy-content, action-text-attachment").each do |node|
      node.replace(node.children) unless node.name == "action-text-attachment"
    end
    document.traverse do |node|
      if node.element? && BLOCKS.include?(node.name)
        boundary = node.name.in?(%w[ul ol li td th]) ? "\n[#{node.name}]\n" : "\n"
        node.add_previous_sibling(Nokogiri::XML::Text.new(boundary, document))
        node.add_next_sibling(Nokogiri::XML::Text.new("\n", document))
      end
    end
    document.text.lines.map { |line| line.gsub(/[[:space:]]+/, " ").strip }.reject(&:empty?).join("\n")
  end
end
