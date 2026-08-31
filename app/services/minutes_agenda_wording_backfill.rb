class MinutesAgendaWordingBackfill
  class SeparationError < StandardError; end

  def self.call(scope: MinutesItem.all)
    new(scope:).call
  end

  def initialize(scope:)
    @scope = scope
  end

  def call
    MinutesItem.transaction do
      eligible_items.find_each { |item| separate!(item) }
    end
  end

  private

  attr_reader :scope

  def eligible_items
    scope
      .joins(minutes_section: :meeting_minutes)
      .where(meeting_minutes: { status: "draft" })
      .where.not(source_dated_agenda_item_id: nil)
      .includes(:rich_text_agenda_body, :rich_text_body, source_dated_agenda_item: :rich_text_body)
  end

  def separate!(item)
    source = item.source_dated_agenda_item
    return unless source.show_wording_in_minutes? && source.rich_text_body.present?
    return if item.agenda_body.present?

    agenda_html = source.rich_text_body.body.to_html
    item.update!(
      agenda_body: ActionText::Content.new(agenda_html),
      body: ActionText::Content.new(recorded_html(item, agenda_html))
    )
  end

  def recorded_html(item, agenda_html)
    current_html = item.rich_text_body&.body&.to_html.to_s
    return "" if current_html == agenda_html

    fragment = Nokogiri::HTML5.fragment(current_html)
    agenda_wrapper = fragment.css("div.lexxy-content").find do |node|
      node.inner_html.strip == agenda_html.strip
    end
    unless agenda_wrapper
      raise SeparationError, "Minutes item #{item.id} does not contain its agenda wording as an exact snapshot"
    end

    agenda_wrapper.remove
    fragment.css("div.lexxy-content").reverse_each { |node| node.replace(node.children) }
    fragment.inner_html.strip
  end
end
