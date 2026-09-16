module PdfDocumentsHelper
  def document_rich_text(content)
    html = content.is_a?(ActionText::RichText) ? content.to_s : sanitize(content.to_s)
    return html unless respond_to?(:pdf_document?, true) && pdf_document?

    fragment = Nokogiri::HTML5.fragment(html)
    fragment.css("img, picture, video, audio, embed, object, iframe").each do |media|
      marker = Nokogiri::XML::Node.new("span", fragment.document)
      marker["class"] = "pdf-omitted-media"
      kind = media.name.in?(%w[img picture]) ? "Image" : "Media"
      description = media["alt"].presence
      marker.content = [ "#{kind} omitted from PDF", description ].compact.join(": ")
      media.replace(marker)
    end
    fragment.to_html.html_safe
  end
end
