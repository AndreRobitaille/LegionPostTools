module EndeavorHistory
  class Presenter
    PAGE_SIZE = 12
    attr_reader :endeavor

    def initialize(endeavor, before: nil)
      @endeavor = endeavor
      @before = before.presence
    end

    def edition
      return @edition if defined?(@edition)
      @edition = endeavor.history_withdrawn? ? nil : endeavor.history_editions.order(id: :desc).first
      if @edition && (@edition.manifest["generation"] != endeavor.history_generation || @edition.manifest["guidance_id"] != endeavor.history_guidances.maximum(:id))
        @edition = nil
      end
      @edition
    end

    def revisions
      @revisions ||= Sources.new(endeavor).revisions.index_by(&:id)
    end

    def source_current?(id, digest)
      revision = revisions[id]
      revision && revision.sha256 == digest
    end

    def overview
      return [] unless edition && edition.manifest["revisions"].all? { |source| source_current?(source["id"], source["sha256"]) }
      edition.payload.fetch("overview")
    end

    def coverage_date
      edition&.payload&.fetch("evidence")&.map { |meeting| Time.iso8601(meeting["date"]) }&.max
    end

    def newer_minutes?
      edition && (revisions.keys - edition.manifest["revisions"].map { |source| source["id"] }).any?
    end

    def upcoming
      agendas.select { |agenda| agenda.starts_at >= Time.current }.sort_by { |agenda| [ agenda.starts_at, agenda.id ] }
    end

    def entries
      @entries ||= begin
        rows = meeting_entries + endeavor.updates.includes(author: :person).map do |update|
          { kind: :update, time: update.created_at, key: "u#{update.id}", update: update }
        end
        rows.sort_by { |row| [ row[:time], row[:key] ] }.reverse
      end
    end

    def page
      selected = entries
      if @before
        index = selected.index { |entry| cursor(entry) == @before }
        selected = index ? selected.drop(index + 1) : []
      end
      selected.first(PAGE_SIZE)
    end

    def next_cursor
      last = page.last
      cursor(last) if last && entries.index(last) < entries.length - 1
    end

    def citations(claim)
      return [] unless edition
      facts = edition.payload.fetch("evidence").flat_map { |meeting| meeting.fetch("facts") }
      ids = facts.select { |fact| claim.fetch("fact_ids").include?(fact["id"]) }.flat_map { |fact| fact["source_ids"] }
      ids.group_by { |id| id.split(":")[0..1] }.filter_map do |(revision_ref, key), unit_ids|
        revision = revisions[revision_ref.delete_prefix("r").to_i]
        next unless revision
        item = source_documents.fetch(revision.id).items.find { |candidate| candidate["key"] == key }
        next unless item
        { label: "#{item['title']} · #{Time.iso8601(revision.payload['starts_at']).strftime('%b %-d, %Y')}",
          url: source_url(revision, key), reader_url: Rails.application.routes.url_helpers.source_endeavor_path(endeavor,
            revision_id: revision.id, record_key: key, unit_ids: unit_ids.uniq),
          source_ids: unit_ids.uniq }
      end
    end

    def source(revision_id:, record_key:, unit_ids:)
      entry = entries.find { |row| row[:kind] == :meeting && row[:revision].id.to_s == revision_id.to_s }
      item = entry && entry[:items].find { |candidate| candidate["key"] == record_key }
      raise ActiveRecord::RecordNotFound unless item
      raise ActiveRecord::RecordNotFound unless unit_ids.is_a?(Array) && unit_ids.all? { |id| id.is_a?(String) }
      requested = unit_ids
      allowed = item["units"].pluck("id")
      raise ActiveRecord::RecordNotFound if requested.empty? || (requested - allowed).any?
      entry.merge(items: [ item.merge("units" => item["units"].select { |unit| requested.include?(unit["id"]) }) ])
    end

    def decision_context(entry, claim)
      evidence = edition.payload.fetch("evidence").find { |meeting| meeting["revision_id"] == entry[:revision].id }
      ids = evidence.fetch("facts").select { |fact| claim["fact_ids"].include?(fact["id"]) }.flat_map { |fact| fact["source_ids"] }
      titles = entry[:decision_titles].to_h { |title| [ title["source_id"], title["text"] ] }
      entry[:items].flat_map { |item| item["units"] }.filter_map do |unit|
        next unless unit["kind"] == "outcome" && ids.include?(unit["id"])
        { title: titles[unit["id"]] || unit["outcome"]["text"], outcome: unit["outcome"] }
      end
    end

    def self.authority(minutes)
      if minutes.membership_approved?
        "Official minutes"
      elsif minutes.reopened? || minutes.approved?
        "Correction in progress — last attested minutes"
      else
        "Attested minutes — awaiting membership approval"
      end
    end

    def source_url(revision, key)
      Rails.application.routes.url_helpers.meeting_minutes_path(revision.meeting_minutes.meeting_id,
        revision: revision.id, anchor: "minutes-item-#{key}")
    end

    private

    def source_documents
      @source_documents ||= revisions.transform_values { |revision| SourceDocument.new(revision) }
    end

    def agendas
      @agendas ||= endeavor.dated_agendas.where(status: "published").includes(:meeting_body, meeting: :minutes).distinct.to_a
    end

    def cursor(entry) = "#{entry[:time].utc.iso8601(6)}|#{entry[:key]}"

    def meeting_entries
      generated = edition ? edition.payload.fetch("evidence").index_by { |meeting| meeting["revision_id"] } : {}
      rows = revisions.values.filter_map do |revision|
        source = generated[revision.id]
        source = nil unless source && source_current?(revision.id, source["sha256"])
        ids = source ? source.fetch("facts").flat_map { |fact| fact["source_ids"] }.uniq : []
        original = source_documents.fetch(revision.id)
        selected = original.items.filter_map do |item|
          primary = item["primary_endeavor_id"] == endeavor.id
          units = item["units"].select { |unit| primary || ids.include?(unit["id"]) }
          next unless primary || units.any?
          item.merge("units" => units, "url" => source_url(revision, item["key"]), "context" => item["units"])
        end
        next if selected.empty?
        account = source && edition.payload.fetch("meetings").find { |meeting| meeting["revision_id"] == revision.id }
        { kind: :meeting, key: "m#{revision.meeting_minutes.meeting_id}", time: Time.iso8601(revision.payload["starts_at"]),
          title: revision.payload["title"], body: revision.payload["meeting_body_name"], revision: revision,
          authority: self.class.authority(revision.meeting_minutes), items: selected, claims: account&.fetch("claims") || [],
          headline: account&.dig("headline", "text"), decision_titles: account&.fetch("decision_titles", []) || [] }
      end
      existing = rows.map { |row| row[:key] }
      agendas.select { |agenda| agenda.starts_at < Time.current }.each do |agenda|
        next if existing.include?("m#{agenda.meeting_id}")
        revision = agenda.meeting.minutes&.member_revision
        rows << { kind: :agenda, key: "m#{agenda.meeting_id}", time: agenda.starts_at, agenda: agenda, revision: revision }
      end
      rows
    end
  end
end
