require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "tmpdir"
require "shellwords"
require "yaml"

# Offline workflow tests. Every production/GitHub/registry boundary is simulated.
class ReleaseTest < Minitest::Test
  HEAD = "f" * 40
  DIGEST = "sha256:#{'a' * 64}"
  REPOSITORY = "ghcr.io/andrerobitaille/legion-post-165-wi-tools"
  SERVICE = "legion_post_165_wi_tools"
  ROOT = File.expand_path("../..", __dir__)

  def setup
    @directory = Dir.mktmpdir("release-test")
    %w[bin lib script config .kamal/hooks commands].each { |path| FileUtils.mkdir_p("#{@directory}/#{path}") }
    %w[bin/release lib/release_image.sh script/verify_production_image.rb .kamal/hooks/pre-deploy config/deploy.yml].each do |path|
      FileUtils.cp("#{ROOT}/#{path}", "#{@directory}/#{path}")
    end
    File.write("#{@directory}/ssh-config", "synthetic config")
    File.write("#{@directory}/identity", "synthetic identity")
    @log = "#{@directory}/commands.jsonl"
    stub("git", <<~'CODE')
      case ARGV.first
      when "symbolic-ref" then puts "master"
      when "rev-parse" then puts ENV.fetch("EXPECTED_HEAD")
      when "diff" then exit 1 if ENV["DIRTY"] == "true"
      when "ls-files" then puts "untracked.txt" if ENV["UNTRACKED"] == "true"
      when "ls-remote" then puts "#{ENV.fetch('REMOTE_HEAD', ENV.fetch('EXPECTED_HEAD'))}\trefs/heads/master"
      end
    CODE
    stub("ssh", <<~'CODE')
      root = ENV.fetch("TEST_DIRECTORY")
      if ARGV.include?("-G")
        puts "identityfile #{root}/identity"
      elsif ARGV.include?("-Nf")
        exit 55 if ENV["FAIL_OPEN"] == "true"
        File.write("#{root}/connected", "yes")
      elsif ARGV.include?("-O")
        if ARGV.include?("exit")
          FileUtils.rm_f("#{root}/connected")
        else
          exit 55 unless File.exist?("#{root}/connected")
        end
      elsif ARGV.last.include?("docker image inspect")
        puts ENV.fetch("IMAGE_METADATA")
      elsif ARGV.last.include?("docker ps")
        if ARGV.last.include?("label=service=legion_post_165_wi_tools ")
          puts "legion_post_165_wi_tools-web-#{ENV.fetch('LIVE_HEAD', ENV.fetch('EXPECTED_HEAD'))}"
        else
          changed = ENV["CHANGE_PROTECTED"] == "true" && File.exist?("#{root}/after-boot")
          puts(changed ? "unexpected-container" : "protected-synthetic-id")
        end
      elsif ARGV.last.include?("docker inspect")
        puts "synthetic-db-id"
      end
    CODE
    stub("curl", 'print ENV.fetch("HTTP_STATUS", "200")')
    stub("kamal", <<~'CODE', directory: "#{@directory}/bin")
      root = ENV.fetch("TEST_DIRECTORY")
      if ARGV.take(2) == %w[build pull]
        FileUtils.rm_f("#{root}/connected") if ENV["LOSE_MASTER"] == "true"
        exit 23 if ENV["FAIL_PULL"] == "true"
      elsif ARGV.first == "deploy"
        abort "build fallback" unless ARGV.include?("--skip-push")
        FileUtils.rm_f("#{root}/connected") if ENV["LOSE_FINAL_MASTER"] == "true"
        ENV["IMAGE_METADATA"] = ENV.fetch("POST_PULL_METADATA", ENV.fetch("IMAGE_METADATA"))
        ENV["KAMAL_VERSION"] = ENV.fetch("FINAL_VERSION", ENV.fetch("EXPECTED_HEAD"))
        exit 24 unless system("#{root}/.kamal/hooks/pre-deploy")
        File.open(ENV.fetch("COMMAND_LOG"), "a") { |f| f.puts JSON.generate(["BOOT", ARGV]) }
        File.write("#{root}/after-boot", "yes")
      end
    CODE
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_verified_image_deploys_and_verifies_with_one_owned_connection
    output, status = session
    assert status.success?, output
    assert_equal 1, calls("BOOT").size, output
    assert_equal 2, calls("ssh").count { |args| args.last.include?("docker image inspect") }
    assert calls("kamal").any? { |args| args.take(2) == %w[deploy --skip-push] && args.include?(HEAD) }
    assert_equal 1, calls("ssh").count { |args| args.include?("-Nf") }
    assert_equal 1, calls("ssh").count { |args| args.include?("exit") }
    remote = calls("ssh").reject { |args| args.include?("-G") || args.include?("-O") || args.include?("-Nf") }
    assert remote.all? { |args| args.include?("ControlMaster=no") && args.include?("ProxyCommand=false") }
    log = File.readlines(@log).map { |line| JSON.parse(line).first }
    assert_operator log.index("BOOT"), :<, log.index("SESSION_STILL_OPEN")
    refute File.exist?("#{@directory}/connected")
    config = JSON.parse(File.read("#{@directory}/transport.json"))
    proxy = Shellwords.split(config.fetch("ssh").fetch("proxy_command"))
    assert_includes proxy, "ControlMaster=no"
    assert_includes proxy, "ProxyCommand=false"
    refute_includes proxy, "ControlMaster=auto"
    assert_equal YAML.safe_load_file("#{ROOT}/config/deploy.yml", aliases: true).except("ssh"), config.except("ssh")
    assert_session_config_routing
  end

  def test_session_kamal_diagnostics_use_generated_config_and_preserve_arguments
    command = "printf synthetic value with spaces"
    output, status = session(commands: Shellwords.join([ "release_kamal", "app", "exec", "--reuse", command ]))
    assert status.success?, output
    assert_equal [ "app", "exec", "--reuse", command ], calls("kamal").last.take(4)
    assert_session_config_routing
    assert_empty calls("BOOT")
    assert_equal 1, calls("ssh").count { |args| args.include?("-Nf") }
    assert_equal 1, calls("SESSION_STILL_OPEN").size
  end

  def test_session_kamal_refuses_caller_supplied_configuration
    options = [ [ "-c", "other.yml" ], [ "-cother.yml" ], [ "--config-file", "other.yml" ],
      [ "--config-file=other.yml" ], [ "--config_file=other.yml" ] ]
    commands = options.map { |arguments| Shellwords.join([ "release_kamal", "app", "details", *arguments ]) }.join("\n")
    output, = session(commands: commands)
    assert_equal options.size, output.scan("release_kamal selects the session configuration").size
    assert_equal [ [ "config" ], [ "server", "exec", "hostname" ] ], calls("kamal").map { |args| args[0...-2] }
    assert_empty calls("BOOT")
    assert_equal 1, calls("SESSION_STILL_OPEN").size
  end

  def test_session_kamal_refuses_lost_master_without_reconnecting
    commands = <<~BASH
      ruby -rfileutils -e 'FileUtils.rm_f(ENV.fetch("TEST_DIRECTORY") + "/connected")'
      release_kamal app details
    BASH
    output, = session(commands: commands)
    assert_equal [ [ "config" ], [ "server", "exec", "hostname" ] ], calls("kamal").map { |args| args[0...-2] }
    assert_includes output, "SSH master lost"
    assert_empty calls("BOOT")
    assert_equal 1, calls("ssh").count { |args| args.include?("-Nf") }
    assert_equal 1, calls("SESSION_STILL_OPEN").size
  end

  def test_missing_or_invalid_digest_cannot_pull_or_replace
    [ "", "latest", "sha256:bad" ].each do |digest|
      FileUtils.rm_f(@log)
      output, = session(digest: digest, variables: { "SHELLOPTS" => "errexit:nounset:pipefail" })
      assert_includes output, "verified sha256 digest"
      assert_empty calls("BOOT")
      assert_equal 1, calls("SESSION_STILL_OPEN").size, output
      refute calls("kamal").any? { |args| %w[build deploy].include?(args.first) }
    end
  end

  def test_wrong_digest_revision_service_and_platform_stop_before_deploy
    variants = [
      image_metadata.merge("RepoDigests" => []),
      image_metadata.merge("Config" => { "Labels" => { "service" => SERVICE, "org.opencontainers.image.revision" => "e" * 40 } }),
      image_metadata.merge("Config" => { "Labels" => { "service" => "other", "org.opencontainers.image.revision" => HEAD } }),
      image_metadata.merge("Architecture" => "arm64"), image_metadata.merge("Os" => "windows"), {}
    ]
    variants.each do |metadata|
      FileUtils.rm_f(@log)
      session(variables: { "IMAGE_METADATA" => JSON.generate(metadata) })
      assert_empty calls("BOOT")
      refute calls("kamal").any? { |args| args.first == "deploy" }
    end
  end

  def test_changed_image_after_final_pull_cannot_replace_containers
    output, = session(variables: { "POST_PULL_METADATA" => JSON.generate(image_metadata.merge("RepoDigests" => [])) })
    assert_empty calls("BOOT"), output
    assert_includes output, "digest mismatch"
    assert calls("kamal").any? { |args| args.first == "deploy" }
    assert_equal 1, calls("SESSION_STILL_OPEN").size
  end

  def test_kamal_version_override_cannot_replace_containers
    output, = session(variables: { "FINAL_VERSION" => "e" * 40 })
    assert_includes output, "Kamal revision does not match"
    assert_empty calls("BOOT")
  end

  def test_dirty_untracked_unpushed_and_failed_pull_are_refused
    [ { "DIRTY" => "true" }, { "UNTRACKED" => "true" }, { "REMOTE_HEAD" => "e" * 40 }, { "FAIL_PULL" => "true" } ].each do |variables|
      FileUtils.rm_f(@log)
      session(variables: variables)
      assert_empty calls("BOOT")
      refute calls("kamal").any? { |args| args.first == "deploy" }
    end
  end

  def test_lost_master_at_both_pull_boundaries_never_reconnects_or_replaces
    %w[LOSE_MASTER LOSE_FINAL_MASTER].each do |failure|
      FileUtils.rm_f(@log)
      output, = session(variables: { failure => "true" })
      assert_includes output, "SSH master lost"
      assert_empty calls("BOOT")
      assert_equal 1, calls("ssh").count { |args| args.include?("-Nf") }
      assert_equal 1, calls("SESSION_STILL_OPEN").size
    end
  end

  def test_failed_initial_connection_stops_without_opening_a_shell
    output, status = session(variables: { "FAIL_OPEN" => "true" })
    refute status.success?, output
    assert_empty calls("SESSION_STILL_OPEN")
    assert_empty calls("kamal")
    assert_equal 1, calls("ssh").count { |args| args.include?("-Nf") }
  end

  def test_stale_live_revision_and_unhealthy_sites_are_reported
    output, = session(variables: { "LIVE_HEAD" => "e" * 40 })
    assert_includes output, "does not match"
    assert_equal 1, calls("BOOT").size
    FileUtils.rm_f(@log)
    output, = session(variables: { "HTTP_STATUS" => "503" })
    assert_includes output, "expected 200"
    assert_empty calls("BOOT")
  end

  def test_changed_cohost_container_is_reported_after_replacement
    output, = session(variables: { "CHANGE_PROTECTED" => "true" })
    assert_equal 1, calls("BOOT").size
    assert_includes output, "protected cohost/database containers changed"
    refute_includes output, "Production revision and all three sites verified"
  end

  def test_hook_and_standalone_deploy_refuse_without_a_session
    %w[verify-image deploy push-deploy setup].each do |command|
      output, status = Open3.capture2e(environment, "bash", "#{@directory}/bin/release", command)
      refute status.success?, output
      assert_empty calls("ssh")
      assert_empty calls("kamal")
    end
  end

  private

  def image_metadata
    { "RepoDigests" => [ "#{REPOSITORY}@#{DIGEST}" ], "Config" => { "Labels" => { "service" => SERVICE, "org.opencontainers.image.revision" => HEAD } }, "Os" => "linux", "Architecture" => "amd64" }
  end

  def assert_session_config_routing
    configs = calls("kamal").map do |args|
      assert_equal 1, args.count("-c")
      assert_equal "-c", args[-2]
      args.last
    end
    assert_equal 1, configs.uniq.size
    assert_match %r{\A/tmp/legion-release\.[^/]+/deploy\.yml\z}, configs.first
    refute File.exist?(File.dirname(configs.first)), "session transport files were not cleaned up"
  end

  def session(digest: DIGEST, variables: {}, commands: "release_deploy")
    input = <<~BASH
      ruby -ryaml -rjson -e 'File.write(ENV.fetch("TEST_DIRECTORY") + "/transport.json", JSON.generate(YAML.safe_load_file(ENV.fetch("release_temp_config"), aliases: true)))'
      #{commands}
      ruby -rjson -e 'File.open(ENV.fetch("COMMAND_LOG"), "a") { |f| f.puts JSON.generate(["SESSION_STILL_OPEN", []]) }'
      exit
    BASH
    Open3.capture2e(environment.merge("RELEASE_IMAGE_DIGEST" => digest).merge(variables), "bash", "#{@directory}/bin/release", "session", stdin_data: input)
  end

  def environment
    {
      "PATH" => "#{@directory}/commands:#{ENV.fetch('PATH')}", "BASH_ENV" => nil,
      "RELEASE_SSH_CONFIG" => "#{@directory}/ssh-config", "BUDDY_CHECK_ACTIVATE_EMAIL" => "",
      "RELEASE_CONTROL_PATH" => nil, "RELEASE_SESSION_ROOT" => nil,
      "EXPECTED_HEAD" => HEAD, "IMAGE_METADATA" => JSON.generate(image_metadata),
      "TEST_DIRECTORY" => @directory, "COMMAND_LOG" => @log
    }
  end

  def calls(command)
    return [] unless File.exist?(@log)
    File.readlines(@log).map { |line| JSON.parse(line) }.filter_map { |name, args| args if name == command }
  end

  def stub(command, body, directory: "#{@directory}/commands")
    File.write("#{directory}/#{command}", <<~CODE)
      #!#{RbConfig.ruby}
      require "json"
      require "fileutils"
      File.open(ENV.fetch("COMMAND_LOG"), "a") { |f| f.puts JSON.generate([#{command.inspect}, ARGV]) }
      #{body}
    CODE
    File.chmod(0o755, "#{directory}/#{command}")
  end
end
