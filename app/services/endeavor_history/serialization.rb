module EndeavorHistory
  module Serialization
    module_function

    def member(endeavor, before: nil)
      history = Presenter.new(endeavor, before: before)
      { overview: history.overview.map { |claim| { text: claim["text"], citations: history.citations(claim) } },
        coverage_date: history.coverage_date&.iso8601, newer_minutes: history.newer_minutes? || false,
        upcoming: history.upcoming.map { |agenda| { id: agenda.id, title: agenda.title, starts_at: agenda.starts_at.iso8601 } },
        entries: history.page.map { |entry| entry_payload(entry, history) }, next_cursor: history.next_cursor }
    end

    def entry_payload(entry, history)
      common = { kind: entry[:kind], date: entry[:time].iso8601 }
      case entry[:kind]
      when :update
        common.merge(author: entry[:update].author.person.full_name, text: entry[:update].body.to_plain_text)
      when :agenda
        common.merge(title: entry[:agenda].title, agenda_id: entry[:agenda].id, minutes_available: entry[:revision].present?)
      when :meeting
        common.merge(title: entry[:title], headline: entry[:headline], decision_titles: entry[:decision_titles], meeting_body: entry[:body], revision_id: entry[:revision].id, authority: entry[:authority],
          claims: entry[:claims].map { |claim| { text: claim["text"], citations: history.citations(claim) } },
          sources: entry[:items].map { |item| item.slice("key", "title", "units", "url") })
      end
    end
  end
end
