module WebsitePublishing
  module Boundary
    # A namespace plus organization ID avoids collisions with other advisory locks.
    def self.synchronize(organization_id)
      ApplicationRecord.transaction do
        bind = ActiveRecord::Relation::QueryAttribute.new("organization_id", Integer(organization_id), ActiveRecord::Type::Integer.new)
        ApplicationRecord.connection.exec_query("SELECT pg_advisory_xact_lock(165927, $1::integer)::text", "Website publication boundary", [ bind ])
        yield
      end
    end
  end
end
