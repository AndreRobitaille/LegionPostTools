module EndeavorHistory
  class Sources
    def initialize(endeavor)
      @endeavor = endeavor
    end

    def revisions
      @revisions ||= @endeavor.organization.meeting_minutes.includes(:membership_approval, :current_revision, revisions: :attestation)
        .order(:starts_at, :id).filter_map(&:member_revision)
    end

    def documents = revisions.map { |revision| SourceDocument.new(revision).payload }

    def manifest
      { "revisions" => revisions.map { |revision| { "id" => revision.id, "sha256" => revision.sha256 } },
        "endeavor" => { "id" => @endeavor.id, "title" => @endeavor.title, "summary" => @endeavor.summary },
        "catalog" => @endeavor.organization.endeavors.order(:id).pluck(:id, :title, :summary),
        "guidance_id" => @endeavor.history_guidances.maximum(:id), "generation" => @endeavor.history_generation,
        "configuration" => Config.signature }
    end

    def self.digest(value) = Digest::SHA256.hexdigest(JSON.generate(value))
  end
end
