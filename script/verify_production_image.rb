# Used without Rails by the runner, publisher and release hook.
require "json"
require "digest"
require "rubygems/package"

mode, revision, *arguments = ARGV
abort "Expected a full source revision" unless revision&.match?(/\A[a-f0-9]{40}\z/)
service = "legion_post_165_wi_tools"
repository = "ghcr.io/andrerobitaille/legion-post-165-wi-tools"

def archive_entry(path, name)
  File.open(path, "rb") do |file|
    Gem::Package::TarReader.new(file) do |tar|
      tar.each do |entry|
        next unless entry.full_name == name && entry.file?
        abort "Oversized image metadata" if entry.size > 1_048_576
        return entry.read
      end
    end
  end
  abort "Missing archive entry #{name}"
end

case mode
when "archive"
  archive, evidence_path = arguments
  # Docker save emits one manifest and configuration, including OCI-layout archives.
  manifest = JSON.parse(archive_entry(archive, "manifest.json"))
  abort "Archive must contain exactly one image" unless manifest.size == 1
  config = archive_entry(archive, manifest.fetch(0).fetch("Config"))
  image = JSON.parse(config)
  evidence = JSON.parse(File.read(evidence_path))
  abort "Archive image/configuration mismatch" unless evidence["image_id"] == "sha256:#{Digest::SHA256.hexdigest(config)}"
  abort "Missing successful smoke evidence" unless evidence.values_at("revision", "service", "platform", "runtime_smoke", "startup_smoke") == [ revision, service, "linux/amd64", "passed", "passed" ]
when "registry"
  image = JSON.parse(STDIN.read)
when "local"
  image = JSON.parse(STDIN.read)
  digest = arguments.fetch(0)
  abort "Prebuilt image digest mismatch" unless Array(image["RepoDigests"]).include?("#{repository}@#{digest}")
  image = { "config" => image["Config"], "os" => image["Os"], "architecture" => image["Architecture"] }
else
  abort "Unknown image verification mode"
end

labels = image.fetch("config").fetch("Labels", {}) || {}
abort "Prebuilt image revision mismatch" unless labels["org.opencontainers.image.revision"] == revision
abort "Prebuilt image service mismatch" unless labels["service"] == service
abort "Prebuilt image must be linux/amd64" unless image["os"] == "linux" && image["architecture"] == "amd64"
puts "Verified #{service} image for #{revision} (#{mode})."
