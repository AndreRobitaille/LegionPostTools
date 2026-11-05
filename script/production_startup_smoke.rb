# Runs inside the actual image, only against the disposable startup-smoke databases.
require "stringio"
abort "Synthetic production databases required" unless Rails.env.production? &&
  %w[POSTGRES_DB POSTGRES_CACHE_DB POSTGRES_QUEUE_DB].map { |key| ENV[key] } == %w[synthetic synthetic_cache synthetic_queue]

ActiveRecord::Migration.check_all_pending!
key = "production-image-smoke"
Rails.cache.write(key, "synthetic", expires_in: 1.minute)
abort "Solid Cache round trip failed" unless Rails.cache.read(key) == "synthetic"
Rails.cache.delete(key)

blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("synthetic image build check"), filename: "synthetic.txt", content_type: "text/plain")
blob_id, storage_key = blob.id, blob.key
blob.purge_later
deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 30
loop do
  # The worker commits on another connection; do not reuse the runner's query cache.
  row_exists = ActiveStorage::Blob.uncached { ActiveStorage::Blob.exists?(blob_id) }
  break unless row_exists || ActiveStorage::Blob.service.exist?(storage_key)
  abort "Solid Queue did not complete synthetic purge job" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
  sleep 0.25
end
puts "All migrations current; primary/queue/cache databases, storage and asynchronous purge succeeded."
