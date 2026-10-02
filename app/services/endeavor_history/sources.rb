module EndeavorHistory
  class Sources
    QUALITY_POLICY = "title-and-financial-context-1".freeze
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
        "quality_policy" => QUALITY_POLICY,
        "configuration" => Config.signature }
    end

    def self.digest(value) = Digest::SHA256.hexdigest(JSON.generate(canonical(value)))

    def self.canonical(value)
      case value
      when Hash then value.stringify_keys.sort.to_h.transform_values { |entry| canonical(entry) }
      when Array then value.map { |entry| canonical(entry) }
      else value
      end
    end

    # Model/prompt releases do not order a paid replay of existing history. They are
    # recorded on attempts; source, identity and human guidance drive automatic work.
    def self.dependencies(manifest) = manifest.except("configuration")

    def self.identity(manifest) = manifest.slice("endeavor", "guidance_id", "generation")
  end
end
