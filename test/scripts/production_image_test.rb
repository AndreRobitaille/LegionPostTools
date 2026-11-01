require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "tmpdir"
require "digest"
require "rubygems/package"
require "zlib"
require "yaml"

# Real scripts and archive bytes; simulated Actions, registry and Docker boundaries.
class ProductionImageTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  HEAD = "f" * 40
  DIGEST = "sha256:#{'a' * 64}"
  SERVICE = "legion_post_165_wi_tools"
  IMAGE = "ghcr.io/andrerobitaille/legion-post-165-wi-tools"

  def setup
    @directory = Dir.mktmpdir("production-image-test")
    %w[bin lib script commands artifact].each { |path| FileUtils.mkdir_p("#{@directory}/#{path}") }
    %w[bin/publish-image script/build_production_image script/verify_production_image.rb lib/production_image.sh].each do |path|
      FileUtils.cp("#{ROOT}/#{path}", "#{@directory}/#{path}")
    end
    @log = "#{@directory}/commands.jsonl"
    @config = { "os" => "linux", "architecture" => "amd64", "config" => { "Labels" => { "service" => SERVICE, "org.opencontainers.image.revision" => HEAD } } }
    @run = { status: "completed", conclusion: "success", head_sha: HEAD, path: ".github/workflows/production_image.yml", event: "push" }
    write_artifact
    stub("git", <<~'CODE')
      case ARGV.first
      when "rev-parse" then puts ENV.fetch("EXPECTED_HEAD")
      when "archive" then STDOUT.binmode.write(File.binread("#{ENV.fetch('TEST_DIRECTORY')}/image.tar"))
      when "diff" then exit 1 if ENV["DIRTY"] == "true"
      when "ls-files" then puts "untracked" if ENV["UNTRACKED"] == "true"
      end
    CODE
    stub("gh", <<~'CODE')
      case ARGV.take(2)
      when ["auth", "token"] then puts "synthetic-token"
      when ["api", "user"] then puts "synthetic-maintainer"
      when ["run", "download"]
        destination = ARGV[ARGV.index("--dir") + 1]
        FileUtils.cp_r(Dir["#{ENV.fetch('TEST_DIRECTORY')}/artifact/*"], destination)
      else puts ENV.fetch("WORKFLOW_RUN")
      end
    CODE
    stub("crane", <<~'CODE')
      case ARGV.first
      when "auth"
        abort "token missing" unless STDIN.read.strip == "synthetic-token"
        File.write("#{ENV.fetch('DOCKER_CONFIG')}/config.json", "synthetic auth")
        File.write("#{ENV.fetch('TEST_DIRECTORY')}/auth-path", ENV.fetch("DOCKER_CONFIG"))
      when "push"
        abort "compressed archive" if File.binread(ARGV[1], 2) == "\x1f\x8b".b
        abort "missing tar manifest" unless File.binread(ARGV[1]).include?("manifest.json")
        abort "wrong tag" unless ARGV[2] == "#{ENV.fetch('EXPECTED_IMAGE')}:#{ENV.fetch('EXPECTED_HEAD')}"
        exit 17 if ENV["FAIL_PUSH"] == "true"
      when "digest" then puts ENV.fetch("PUBLISHED_DIGEST")
      when "config" then puts ENV.fetch("PUBLISHED_CONFIG")
      end
    CODE
    # These two fixtures represent successful actual-image smokes, not real image execution.
    File.write("#{@directory}/script/profile_production_image", <<~'BASH')
      set -eu
      [[ "${FAIL_RUNTIME:-}" != true ]] || exit 18
      printf '%s\n' "$1" > "$3/revision.txt"
      echo synthetic:verified > "$3/image-ref.txt"
      echo simulated-runtime > "$3/smoke.txt"
    BASH
    File.write("#{@directory}/script/smoke_production_startup", <<~'BASH')
      set -eu
      [[ "$1" == synthetic:verified && "${FAIL_STARTUP:-}" != true ]] || exit 19
      echo simulated-startup
    BASH
    stub("docker", <<~'CODE')
      abort "remote Docker boundary" unless ARGV.shift(2) == ["--host", "unix:///var/run/docker.sock"]
      case ARGV.first
      when "image" then puts JSON.generate([{ "Id" => ENV.fetch("IMAGE_ID") }])
      when "save" then STDOUT.binmode.write(File.binread("#{ENV.fetch('TEST_DIRECTORY')}/image.tar"))
      when "inspect" then puts JSON.generate({ "Memory" => 0, "MemorySwap" => 0 })
      end
    CODE
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_manual_publication_verifies_archive_and_published_image_and_cleans_credentials
    output, status = publish
    assert status.success?, output
    assert_includes output, "RELEASE_IMAGE_DIGEST=#{DIGEST}"
    assert calls("gh").any? { |args| args.include?("production-image-#{HEAD}") }
    assert calls("crane").any? { |args| args == [ "push", args[1], "#{IMAGE}:#{HEAD}" ] }
    assert calls("crane").any? { |args| args == [ "config", "#{IMAGE}@#{DIGEST}" ] }
    refute_includes output, "synthetic-token"
    refute File.exist?(File.read("#{@directory}/auth-path"))
    assert_empty calls("docker")
  end

  def test_unsuccessful_wrong_revision_wrong_workflow_and_pr_runs_cannot_publish
    [ { conclusion: "failure" }, { status: "in_progress" }, { head_sha: "e" * 40 }, { path: "other.yml" }, { event: "pull_request" } ].each do |change|
      FileUtils.rm_f(@log)
      output, status = publish("WORKFLOW_RUN" => JSON.generate(@run.merge(change)))
      refute status.success?, output
      assert_empty calls("crane")
    end
  end

  def test_corrupt_incomplete_or_wrong_revision_evidence_never_authenticates
    [ :corrupt, :gzip, :incomplete, :revision, :image_id, :smoke ].each do |fault|
      write_artifact
      FileUtils.rm_f(@log)
      case fault
      when :corrupt then File.write("#{@directory}/artifact/image.tar.gz", "corrupt")
      when :gzip then File.write("#{@directory}/artifact/image.tar.gz", "not gzip"); write_checksums
      when :incomplete then File.write("#{@directory}/artifact/SHA256SUMS", "")
      when :revision then File.write("#{@directory}/artifact/revision.txt", "e" * 40); write_checksums
      when :image_id then write_evidence(image_id: "sha256:#{'0' * 64}"); write_checksums
      when :smoke then write_evidence(startup_smoke: "failed"); write_checksums
      end
      output, status = publish
      refute status.success?, "#{fault}: #{output}"
      assert_empty calls("crane"), fault.to_s
    end
  end

  def test_wrong_archive_service_revision_os_or_architecture_never_authenticates
    original = Marshal.dump(@config)
    [ [ "architecture", "arm64" ], [ "os", "windows" ], [ "service", "other" ], [ "org.opencontainers.image.revision", "e" * 40 ] ].each do |key, value|
      FileUtils.rm_f(@log)
      @config = Marshal.load(original)
      if @config.key?(key)
        @config[key] = value
      else
        @config["config"]["Labels"][key] = value
      end
      write_artifact
      output, status = publish
      refute status.success?, output
      assert_empty calls("crane")
    end
  end

  def test_wrong_registry_configuration_or_digest_does_not_offer_release_evidence
    [ { "PUBLISHED_CONFIG" => JSON.generate(@config.merge("architecture" => "arm64")) }, { "PUBLISHED_DIGEST" => "latest" }, { "FAIL_PUSH" => "true" } ].each do |fault|
      output, status = publish(fault)
      refute status.success?, output
      refute_includes output, "RELEASE_IMAGE_DIGEST="
      refute File.exist?(File.read("#{@directory}/auth-path"))
    end
  end

  def test_publication_requires_a_manual_clean_checkout
    [ { "CI" => "true" }, { "GITHUB_ACTIONS" => "true" }, { "DIRTY" => "true" }, { "UNTRACKED" => "true" } ].each do |fault|
      FileUtils.rm_f(@log)
      output, status = publish(fault)
      refute status.success?, output
      assert_empty calls("gh")
      assert_empty calls("crane")
    end
  end

  def test_simulated_build_exports_only_after_both_smokes_with_revision_checksums
    output, status = build
    assert status.success?, output
    artifact = "#{@directory}/output/image"
    assert_equal "#{HEAD}\n", File.read("#{artifact}/revision.txt")
    assert_equal %w[passed passed], JSON.parse(File.read("#{artifact}/evidence.json")).values_at("runtime_smoke", "startup_smoke")
    assert_equal 3, File.readlines("#{artifact}/SHA256SUMS").size
    check_output, check_status = Open3.capture2e("sha256sum", "--check", "SHA256SUMS", chdir: artifact)
    assert check_status.success?, check_output
    assert_equal 1, calls("docker").count { |args| args.include?("save") }
    assert_empty calls("gh")
    assert_empty calls("crane")
  end

  def test_failed_runtime_or_startup_smoke_never_exports_even_after_a_previous_success
    %w[FAIL_RUNTIME FAIL_STARTUP].each do |fault|
      _, status = build
      assert status.success?
      FileUtils.rm_f(@log)
      output, status = build(fault => "true")
      refute status.success?, output
      refute File.exist?("#{@directory}/output/image/image.tar.gz")
      refute File.exist?("#{@directory}/output/image/SHA256SUMS")
      refute calls("docker").any? { |args| args.include?("save") }
    end
  end

  def test_workstation_self_hosted_remote_docker_and_wrong_architecture_are_rejected
    [ { "GITHUB_ACTIONS" => nil }, { "RUNNER_ENVIRONMENT" => "self-hosted" }, { "RUNNER_ARCH" => "ARM64" }, { "DOCKER_HOST" => "ssh://production.invalid" }, { "DOCKER_CONTEXT" => "production" } ].each do |fault|
      FileUtils.rm_f(@log)
      output, status = build(fault)
      refute status.success?, output
      assert_empty calls("docker")
      refute File.exist?("#{@directory}/output/image/image.tar.gz")
    end
  end

  def test_workflow_only_builds_and_exports_without_publication_or_production_access
    workflow = YAML.load_file("#{ROOT}/.github/workflows/production_image.yml")
    events = workflow["on"] || workflow[true]
    assert_equal [ "master" ], events.fetch("push").fetch("branches")
    assert events.key?("pull_request")
    assert events.key?("workflow_dispatch")
    assert_equal({ "contents" => "read" }, workflow.fetch("permissions"))
    job = workflow.fetch("jobs").fetch("build")
    assert_equal "ubuntu-latest", job.fetch("runs-on")
    steps = job.fetch("steps")
    assert_equal false, steps.first.fetch("with").fetch("persist-credentials")
    assert_includes steps.filter_map { |step| step["run"] }.join, 'script/build_production_image "$GITHUB_SHA"'
    refute_match(/publish-image|bin\/release|kamal|docker (?:push|login)/, steps.filter_map { |step| step["run"] }.join)
    refute_match(/secrets\./, JSON.generate(workflow))
    export = steps.last
    assert_equal "success() && github.event_name != 'pull_request'", export.fetch("if")
    assert_equal "production-image-${{ github.sha }}", export.fetch("with").fetch("name")
  end

  def test_implicit_kamal_builds_are_refused
    output, status = Open3.capture2e("bash", "#{ROOT}/.kamal/hooks/pre-build")
    refute status.success?
    assert_includes output, "--skip-push"
    assert_empty calls("docker")
    assert_empty calls("crane")
  end

  def test_missing_builder_resource_limits_stop_before_compilation
    FileUtils.cp("#{ROOT}/script/profile_production_image", "#{@directory}/script/profile_production_image")
    output, status = build
    refute status.success?, output
    assert_includes output, "Missing 1536 MiB builder limits"
    refute calls("docker").any? { |args| args.include?("build") || args.include?("save") }
    assert calls("docker").any? { |args| args.include?("rm") }, "failed builder was not cleaned up"
  end

  private

  def write_artifact
    config = JSON.generate(@config)
    @image_id = "sha256:#{Digest::SHA256.hexdigest(config)}"
    File.open("#{@directory}/image.tar", "wb") do |file|
      Gem::Package::TarWriter.new(file) do |tar|
        { "manifest.json" => JSON.generate([ { "Config" => "config.json", "Layers" => [] } ]), "config.json" => config }.each do |name, contents|
          tar.add_file_simple(name, 0o600, contents.bytesize) { |entry| entry.write(contents) }
        end
      end
    end
    Zlib::GzipWriter.open("#{@directory}/artifact/image.tar.gz") { |gzip| gzip.write(File.binread("#{@directory}/image.tar")) }
    File.write("#{@directory}/artifact/revision.txt", "#{HEAD}\n")
    write_evidence
    write_checksums
  end

  def write_evidence(**changes)
    File.write("#{@directory}/artifact/evidence.json", JSON.generate({ revision: HEAD, service: SERVICE, platform: "linux/amd64", image_id: @image_id, runtime_smoke: "passed", startup_smoke: "passed" }.merge(changes)))
  end

  def write_checksums
    File.write("#{@directory}/artifact/SHA256SUMS", %w[image.tar.gz revision.txt evidence.json].map { |name| "#{Digest::SHA256.file("#{@directory}/artifact/#{name}").hexdigest}  #{name}\n" }.join)
  end

  def environment
    {
      "PATH" => "#{@directory}/commands:#{ENV.fetch('PATH')}",
      "CRANE" => "#{@directory}/commands/crane", "BASH_ENV" => nil,
      "TEST_DIRECTORY" => @directory, "COMMAND_LOG" => @log,
      "EXPECTED_HEAD" => HEAD, "EXPECTED_IMAGE" => IMAGE,
      "WORKFLOW_RUN" => JSON.generate(@run), "PUBLISHED_DIGEST" => DIGEST,
      "PUBLISHED_CONFIG" => JSON.generate(@config), "IMAGE_ID" => @image_id,
      "CI" => nil, "GITHUB_ACTIONS" => nil, "DOCKER_HOST" => nil,
      "DOCKER_CONTEXT" => nil, "DOCKER_TLS_VERIFY" => nil, "DOCKER_CERT_PATH" => nil
    }
  end

  def publish(variables = {})
    Open3.capture2e(environment.merge(variables), "bash", "#{@directory}/bin/publish-image", "123")
  end

  def build(variables = {})
    runner = { "GITHUB_ACTIONS" => "true", "RUNNER_ENVIRONMENT" => "github-hosted", "RUNNER_OS" => "Linux", "RUNNER_ARCH" => "X64" }
    Open3.capture2e(environment.merge(runner).merge(variables), "bash", "#{@directory}/script/build_production_image", HEAD, "#{@directory}/output")
  end

  def calls(command)
    return [] unless File.exist?(@log)
    File.readlines(@log).map { |line| JSON.parse(line) }.filter_map { |name, args| args if name == command }
  end

  def stub(command, body)
    File.write("#{@directory}/commands/#{command}", <<~CODE)
      #!#{RbConfig.ruby}
      require "json"
      require "fileutils"
      File.open(ENV.fetch("COMMAND_LOG"), "a") { |f| f.puts JSON.generate([#{command.inspect}, ARGV]) }
      #{body}
    CODE
    File.chmod(0o755, "#{@directory}/commands/#{command}")
  end
end
