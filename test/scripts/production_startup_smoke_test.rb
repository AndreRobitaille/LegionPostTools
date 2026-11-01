require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "open3"
require "json"

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

# Script workflow simulation; actual image/resource acceptance runs in Actions.
class ProductionStartupWorkflowTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def setup
    @directory = Dir.mktmpdir("startup-workflow-test")
    %w[script lib commands output].each { |path| FileUtils.mkdir_p("#{@directory}/#{path}") }
    %w[script/smoke_production_startup lib/production_image.sh].each do |path|
      FileUtils.cp("#{ROOT}/#{path}", "#{@directory}/#{path}")
    end
    @log = "#{@directory}/commands.jsonl"
    File.write("#{@directory}/commands/docker", <<~'CODE'.sub("RUBY_EXECUTABLE", RbConfig.ruby))
      #!RUBY_EXECUTABLE
      require "json"
      abort "unexpected Docker transport" unless ARGV.shift(2) == ["--host", "unix:///var/run/docker.sock"]
      File.open(ENV.fetch("COMMAND_LOG"), "a") { |file| file.puts JSON.generate(ARGV) }
      case ARGV.first
      when "run"
        exit 137 if ARGV.include?("runner")
      when "exec"
        # Reproduce the old in-app runner's failure if that boundary regresses.
        exit 137 if ARGV.include?("runner")
        if ARGV.include?("psql")
          puts "1"
        elsif ARGV.last.end_with?("/session/new")
          puts '<link href="/assets/synthetic.css" rel="stylesheet">'
        elsif ARGV.last.end_with?(".css")
          puts "synthetic stylesheet"
        end
      when "inspect"
        state = ARGV.last.end_with?("-verification") ? { "OOMKilled" => true, "ExitCode" => 137 } : { "OOMKilled" => false, "Running" => true }
        puts JSON.generate(ARGV.include?("{{json .State}}") ? state : { "Memory" => 536870912, "MemorySwap" => 536870912 })
      end
    CODE
    File.chmod(0o755, "#{@directory}/commands/docker")
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_separate_verification_failure_preserves_resource_evidence_and_cleans_shared_storage
    environment = {
      "PATH" => "#{@directory}/commands:#{ENV.fetch('PATH')}", "COMMAND_LOG" => @log,
      "GITHUB_ACTIONS" => "true", "RUNNER_ENVIRONMENT" => "github-hosted", "RUNNER_OS" => "Linux", "RUNNER_ARCH" => "X64",
      "DOCKER_HOST" => nil, "DOCKER_CONTEXT" => nil, "DOCKER_TLS_VERIFY" => nil, "DOCKER_CERT_PATH" => nil, "BASH_ENV" => nil
    }
    output, status = Open3.capture2e(environment, "bash", "#{@directory}/script/smoke_production_startup", "synthetic:image", "#{@directory}/output")
    assert_equal 137, status.exitstatus, output
    calls = File.readlines(@log).map { |line| JSON.parse(line) }
    app = calls.find { |args| args.first == "run" && args.any? { |arg| arg.end_with?("-app") } }
    probe = calls.find { |args| args.first == "run" && args.include?("runner") }
    refute_nil probe, "verification must not add a Rails process to the app cgroup"
    app_name = app[app.index("--name") + 1]
    probe_name = probe[probe.index("--name") + 1]
    assert_includes probe, "--volumes-from"
    assert_equal app_name, probe[probe.index("--volumes-from") + 1]
    assert_equal app[app.index("--network") + 1], probe[probe.index("--network") + 1]
    [ app, probe ].each do |args|
      assert_equal "512m", args[args.index("--memory") + 1]
      assert_equal "512m", args[args.index("--memory-swap") + 1]
      assert_includes args, "POSTGRES_DB=synthetic"
    end
    assert JSON.parse(File.read("#{@directory}/output/verification-state.json")).fetch("OOMKilled")
    refute JSON.parse(File.read("#{@directory}/output/startup-state.json")).fetch("OOMKilled")
    assert_equal 536870912, JSON.parse(File.read("#{@directory}/output/verification-config.json")).fetch("Memory")
    removal = calls.find { |args| args.take(2) == %w[rm -fv] }
    assert_includes removal, app_name
    assert_includes removal, probe_name
    storage = app[app.index("--volume") + 1].split(":").first
    assert_includes calls, [ "volume", "rm", storage ]
    assert_includes calls, [ "network", "rm", app[app.index("--network") + 1] ]
  end
end
