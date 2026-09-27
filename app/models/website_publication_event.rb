class WebsitePublicationEvent < ApplicationRecord
  belongs_to :website_publication
  before_update { raise ActiveRecord::ReadOnlyRecord, "Publication history is append-only" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "Publication history is append-only" }
end
