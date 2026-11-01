require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

class ReleaseTest < Minitest::Test
  HEAD = "f" * 40
  DIGEST = "sha256:#{'a' * 64}"
  REPOSITORY = "ghcr.io/andrerobitaille/legion-post-165-wi-tools"
  SERVICE = "legion_post_165_wi_tools"

  def setup
    @directory = Dir.mktmpdir("release-test")
    FileUtils.mkdir_p([ "#{@directory}/bin", "#{@directory}/config", "#{@directory}/commands" ])
    FileUtils.cp(File.expand_path("../../bin/release", __dir__), "#{@directory}/bin/release")
    File.write("#{@directory}/config/deploy.yml", "service: #{SERVICE}\n")
    File.write("#{@directory}/ssh-config", "synthetic config")
    File.write("#{@directory}/identity", "synthetic identity")
    @log = "#{@directory}/commands.jsonl"
    stub("git", <<~'RUBY')
      case ARGV.first
      when "symbolic-ref" then puts "master"
      when "rev-parse" then puts ENV.fetch("EXPECTED_HEAD")
      when "ls-remote" then puts "#{ENV.fetch('EXPECTED_HEAD')}\trefs/heads/master"
      end
    RUBY
    stub("ssh", <<~'RUBY')
      if ARGV.include?("-G")
        puts "controlpath #{ENV.fetch('TEST_DIRECTORY')}/control"
        puts "identityfile #{ENV.fetch('TEST_DIRECTORY')}/identity"
      elsif ARGV.last.include?("docker image inspect")
        puts ENV.fetch("IMAGE_METADATA")
      elsif ARGV.last.include?("docker ps")
        puts "legion_post_165_wi_tools-web-#{ENV.fetch('EXPECTED_HEAD')}"
      elsif !ARGV.include?("-O") && ENV["FAIL_REMOTE"] == "true"
        exit 55
      end
    RUBY
    stub("curl", 'print "200"')
    stub("kamal", "", directory: "#{@directory}/bin")
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_verified_image_skips_build_and_uses_retained_connection
    output, status = release
    assert status.success?, output
    assert_includes calls("kamal").map(&:first), "config"
    assert calls("kamal").any? { |args| args.take(2) == %w[build pull] }
    assert calls("kamal").any? { |args| args.take(2) == %w[deploy --skip-push] }
    remote_calls = calls("ssh").reject { |args| args.include?("-G") || args.include?("-O") }
    assert remote_calls.all? { |args| args.include?("ControlMaster=no") && args.include?("ProxyCommand=false") }
  end

  def test_wrong_digest_cannot_deploy
    image_metadata["RepoDigests"] = [ "#{REPOSITORY}@sha256:#{'b' * 64}" ]
    assert_rejected("digest mismatch")
  end

  def test_stale_revision_cannot_deploy
    image_metadata["Config"]["Labels"]["org.opencontainers.image.revision"] = "e" * 40
    assert_rejected("revision mismatch")
  end

  def test_wrong_service_cannot_deploy
    image_metadata["Config"]["Labels"]["service"] = "another_app"
    assert_rejected("service mismatch")
  end

  def test_wrong_architecture_cannot_deploy
    image_metadata["Architecture"] = "arm64"
    assert_rejected("linux/amd64")
  end

  def test_invalid_digest_stops_before_any_remote_command
    output, status = release(digest: "latest")
    refute status.success?
    assert_includes output, "must be a sha256 digest"
    assert_empty calls("ssh")
    assert_empty calls("kamal")
  end

  def test_default_path_still_builds
    output, status = release(digest: "")
    assert status.success?, output
    assert calls("kamal").any? { |args| args.first == "deploy" && !args.include?("--skip-push") }
    refute calls("kamal").any? { |args| args.take(2) == %w[build pull] }
  end

  def test_lost_master_stops_without_reconnecting_or_deploying
    output, status = release(variables: { "FAIL_REMOTE" => "true" })
    refute status.success?, output
    refute calls("ssh").any? { |args| args.include?("-MNf") }
    assert_empty calls("kamal")
  end

  private

  def image_metadata
    @image_metadata ||= {
      "RepoDigests" => [ "#{REPOSITORY}@#{DIGEST}" ],
      "Config" => { "Labels" => { "service" => SERVICE, "org.opencontainers.image.revision" => HEAD } },
      "Os" => "linux", "Architecture" => "amd64"
    }
  end

  def release(digest: DIGEST, variables: {})
    environment = {
      "PATH" => "#{@directory}/commands:#{ENV.fetch('PATH')}",
      "RELEASE_SSH_CONFIG" => "#{@directory}/ssh-config",
      "RELEASE_KEEP_SSH_MASTER" => "false", "BUDDY_CHECK_ACTIVATE_EMAIL" => "",
      "RELEASE_IMAGE_DIGEST" => digest, "EXPECTED_HEAD" => HEAD,
      "IMAGE_METADATA" => JSON.generate(image_metadata), "TEST_DIRECTORY" => @directory,
      "COMMAND_LOG" => @log
    }
    Open3.capture2e(environment.merge(variables), "bash", "#{@directory}/bin/release", "deploy")
  end

  def assert_rejected(message)
    output, status = release
    refute status.success?, output
    assert_includes output, message
    refute calls("kamal").any? { |args| args.first == "deploy" }
  end

  def calls(command)
    return [] unless File.exist?(@log)
    File.readlines(@log).map { |line| JSON.parse(line) }.filter_map { |name, args| args if name == command }
  end

  def stub(command, body, directory: "#{@directory}/commands")
    File.write("#{directory}/#{command}", <<~RUBY)
      #!#{RbConfig.ruby}
      require "json"
      File.open(ENV.fetch("COMMAND_LOG"), "a") { |file| file.puts JSON.generate([ #{command.inspect}, ARGV ]) }
      #{body}
    RUBY
    File.chmod(0o755, "#{directory}/#{command}")
  end
end
