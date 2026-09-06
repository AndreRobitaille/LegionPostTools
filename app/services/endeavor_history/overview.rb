module EndeavorHistory
  class Overview
    LABELS = { "all" => "All", "attention" => "Needs attention", "processing" => "Processing",
      "failed" => "Failed", "outdated" => "Outdated", "not_generated" => "Not generated",
      "withdrawn" => "Withdrawn", "no_minutes" => "No minutes yet", "current" => "Current" }.freeze
    FILTERS = %w[all attention processing failed outdated not_generated withdrawn].freeze
    ATTENTION = %w[failed outdated not_generated].freeze

    def initialize(organization)
      @organization = organization
    end

    def rows
      @rows ||= begin
        endeavors = @organization.endeavors.order(:title, :id).to_a
        ids = endeavors.map(&:id)
        editions = EndeavorHistoryEdition.where(endeavor_id: ids).select("DISTINCT ON (endeavor_id) endeavor_id, manifest, created_at").order(:endeavor_id, id: :desc).index_by(&:endeavor_id)
        runs = EndeavorHistoryRun.where(endeavor_id: ids).select("DISTINCT ON (endeavor_id) endeavor_id, status").order(:endeavor_id, id: :desc).index_by(&:endeavor_id)
        guidance = EndeavorHistoryGuidance.where(endeavor_id: ids).group(:endeavor_id).maximum(:id)
        common = endeavors.any? ? Sources.new(endeavors.first).manifest.slice("revisions", "catalog", "configuration") : {}
        endeavors.map do |endeavor|
          edition = editions[endeavor.id]
          manifest = common.merge("endeavor" => endeavor.slice(:id, :title, :summary),
            "guidance_id" => guidance[endeavor.id], "generation" => endeavor.history_generation)
          { endeavor: endeavor, published_at: edition&.created_at,
            status: status(endeavor, runs[endeavor.id], edition, manifest) }
        end
      end
    end

    def filtered(filter)
      return rows if filter == "all"
      statuses = filter == "attention" ? ATTENTION : [ filter ]
      rows.select { |row| statuses.include?(row[:status]) }
    end

    private

    def status(endeavor, run, edition, manifest)
      return "withdrawn" if endeavor.history_withdrawn?
      return "processing" if run&.status.in?(%w[pending running])
      return "failed" if run&.status == "failed"
      return "no_minutes" if manifest.fetch("revisions").empty?
      return "not_generated" unless edition
      edition.manifest == manifest ? "current" : "outdated"
    end
  end
end
