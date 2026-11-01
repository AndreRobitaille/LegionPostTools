require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "open3"

# Component simulation, not Rails boot, a database, or execution of an image.
class ProductionStartupSmokeTest < Minitest::Test
  SCRIPT = File.expand_path("../../script/production_startup_smoke.rb", __dir__)

  def setup
    @directory = Dir.mktmpdir("startup-smoke-test")
    @bootstrap = "#{@directory}/synthetic_runtime.rb"
    File.write(@bootstrap, <<~'CODE')
      require "ostruct"
      class Integer
        def minute = self * 60
      end
      module Rails
        def self.env = OpenStruct.new(production?: true)
        def self.cache = @cache ||= Object.new.tap do |cache|
          def cache.write(key, value, **) = @value = value
          def cache.read(key) = @value
          def cache.delete(key) = @value = nil
        end
      end
      module ActiveRecord
        class Migration
          def self.check_all_pending!
            File.write(ENV.fetch("MIGRATION_MARKER"), "checked")
          end
        end
      end
      module ActiveStorage
        class Blob
          def self.create_and_upload!(io:, **)
            abort "unexpected synthetic input" unless io.read == "synthetic image build check"
            new
          end
          def id = 1
          def key = "synthetic-key"
          def purge_later = self.class.instance_variable_set(:@queued, true)
          def self.uncached
            @fresh = true
            yield
          ensure
            @fresh = false
          end
          def self.exists?(id)
            abort "purge was not enqueued" unless @queued
            # Simulate a stale runner query cache and a worker committing after poll one.
            return true unless @fresh
            @reads = (@reads || 0) + 1
            ENV["STALLED_JOB"] == "true" || @reads < 2
          end
          def self.service = self
          def self.exist?(key) = false
        end
      end
      def Process.clock_gettime(*) = @synthetic_time = (@synthetic_time || 0) + 10
    CODE
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_later_worker_commit_is_observed_without_reusing_query_cache
    output, status = smoke
    assert status.success?, output
    assert_includes output, "asynchronous purge succeeded"
    assert File.exist?("#{@directory}/migration-checked")
  end

  def test_an_enqueued_job_without_completion_is_not_success
    output, status = smoke("STALLED_JOB" => "true")
    refute status.success?, output
    assert_includes output, "did not complete synthetic purge job"
  end

  def test_non_synthetic_databases_are_refused_before_database_checks
    output, status = smoke("POSTGRES_DB" => "not-the-synthetic-database")
    refute status.success?, output
    assert_includes output, "Synthetic production databases required"
    refute File.exist?("#{@directory}/migration-checked")
  end

  private

  def smoke(variables = {})
    environment = {
      "POSTGRES_DB" => "synthetic", "POSTGRES_CACHE_DB" => "synthetic_cache",
      "POSTGRES_QUEUE_DB" => "synthetic_queue", "MIGRATION_MARKER" => "#{@directory}/migration-checked",
      "STALLED_JOB" => nil
    }
    Open3.capture2e(environment.merge(variables), RbConfig.ruby, "-r", @bootstrap, SCRIPT)
  end
end
