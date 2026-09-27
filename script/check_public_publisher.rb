# RAILS_ENV=test bin/rails runner script/check_public_publisher.rb
# Read-only live contract check. No credentials, content writes or grant changes.
require "net/http"
require "fileutils"
require "vips"

origin = ENV.fetch("CHECK_PUBLISHER_ORIGIN", "http://localhost:3105")
connect_origin = ENV.fetch("CHECK_PUBLISHER_CONNECT_ORIGIN", origin)
companion = ENV.fetch("PUBLIC_SITE_REPO", "../wipost165")
%w[unavailable not_found response contract transport client].each do |name|
  require File.expand_path("app/services/publishing/#{name}.rb", companion)
end
contract = Publishing::Contract.new(origin: origin)
output = Pathname.new(ENV.fetch("PUBLISHER_EXAMPLES_DIR", Rails.root.join("tmp/publisher-examples").to_s))
FileUtils.mkdir_p(output)
headers_to_keep = %w[content-type cache-control date age etag retry-after allow]
responses = {}
fetch = lambda do |name, path, method = :get, etag = nil|
  uri = URI(connect_origin + path)
  request = (method == :head ? Net::HTTP::Head : Net::HTTP::Get).new(uri)
  request["Accept"] = "application/json"
  request["If-None-Match"] = etag if etag
  result = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 1, read_timeout: 2) { |http| http.request(request) }
  responses[name] = { status: result.code.to_i, headers: result.to_hash.slice(*headers_to_keep).transform_values(&:first), bytes: result.body.to_s.bytesize }
  result
end
featured = fetch.call("featured", "/public/v1/featured_members")
raise "Featured failed" unless featured.code == "200"
featured_data = contract.validate!(JSON.parse(featured.body), kind: :featured)
File.write(output.join("featured.json"), JSON.pretty_generate(featured_data) + "\n")
raise "Conditional failed" unless fetch.call("featured_conditional", "/public/v1/featured_members", :get, featured["etag"]).code == "304"
raise "HEAD failed" unless fetch.call("featured_head", "/public/v1/featured_members", :head).code == "200"
featured_data.fetch("members").each_with_index do |member, index|
  path = "/public/v1/member_stories/#{member.fetch('id')}"
  detail = fetch.call("story_#{index}", path)
  contract.validate!(JSON.parse(detail.body), kind: :story, id: member.fetch("id"))
  File.write(output.join("story_#{index}.json"), JSON.pretty_generate(JSON.parse(detail.body)) + "\n")
  member.fetch("portrait").fetch("variants").each do |variant|
    image_path = URI(variant.fetch("url")).path
    image = fetch.call("portrait_#{index}_#{variant.fetch('size')}", image_path)
    raise "Portrait failed" unless image.code == "200" && image["content-type"] == "image/webp"
    decoded = Vips::Image.new_from_buffer(image.body, "")
    raise "Wrong portrait dimensions" unless [ decoded.width, decoded.height ] == variant.values_at("width", "height")
    File.binwrite(output.join("portrait_#{index}_#{variant.fetch('size')}.webp"), image.body)
    raise "Image conditional failed" unless fetch.call("portrait_#{index}_#{variant.fetch('size')}_conditional", image_path, :get, image["etag"]).code == "304"
    raise "Image HEAD failed" unless fetch.call("portrait_#{index}_#{variant.fetch('size')}_head", image_path, :head).code == "200"
  end
end
from = Date.new(2026, 10, 1)
to = Date.new(2026, 11, 1)
events = fetch.call("events", "/public/v1/events?from=#{from}&to=#{to}")
raise "Events failed" unless events.code == "200"
events_data = contract.validate!(JSON.parse(events.body), kind: :events, from: from, to: to)
File.write(output.join("events.json"), JSON.pretty_generate(events_data) + "\n")
events_data.fetch("events").each_with_index do |event, index|
  detail = fetch.call("event_#{index}", "/public/v1/events/#{event.fetch('id')}")
  contract.validate!(JSON.parse(detail.body), kind: :event, id: event.fetch("id"))
  File.write(output.join("event_#{index}.json"), JSON.pretty_generate(JSON.parse(detail.body)) + "\n")
end
unknown = fetch.call("not_found", "/public/v1/member_stories/unknown")
raise "404 failed" unless unknown.code == "404" && unknown["cache-control"] == "no-store"
File.write(output.join("not_found.json"), JSON.pretty_generate(JSON.parse(unknown.body)) + "\n")
invalid = fetch.call("invalid_interval", "/public/v1/events")
raise "400 failed" unless invalid.code == "400" && invalid["cache-control"] == "no-store"
File.write(output.join("invalid_interval.json"), JSON.pretty_generate(JSON.parse(invalid.body)) + "\n")
File.write(output.join("responses.json"), JSON.pretty_generate(responses) + "\n")
puts "Companion Contract accepted #{featured_data.fetch('members').size} stories and #{events_data.fetch('events').size} events, including details and both WebP sizes."
puts "GET, HEAD, 304, 400 and 404 verified. Captured #{responses.size} responses in #{output}."

# The HTTPS-only consumer can be exercised against a publisher advertising an
# HTTPS origin through an explicit LOCAL test transport. Production TLS policy
# remains unchanged. No response bodies or portrait URLs are rewritten.
if URI(origin).scheme == "https"
  transport = lambda do |uri, headers|
    Publishing::Transport.new.call(URI(connect_origin + uri.request_uri), headers)
  end
  client = Publishing::Client.new(origin: origin, cache: ActiveSupport::Cache::MemoryStore.new, transport: transport)
  members = client.featured
  members.each { |member| client.story(member.fetch("id")) }
  client.events(from: from, to: to).fetch("events").each { |event| client.event(event.fetch("id")) }
  puts "Companion Client accepted collections and all details through the explicit test transport."

  now = Time.now.to_f
  unavailable = false
  aged_transport = lambda do |uri, headers|
    if unavailable
      Publishing::Response.new(status: 503, headers: { "cache-control" => "no-store", "retry-after" => "60" }, body: "")
    else
      result = transport.call(uri, headers)
      Publishing::Response.new(status: result.status, headers: result.headers.merge("age" => "240"), body: result.body)
    end
  end
  cache = ActiveSupport::Cache::MemoryStore.new
  aged_client = Publishing::Client.new(origin: origin, cache: cache, transport: aged_transport, clock: -> { now })
  aged_client.featured
  unavailable = true
  now += 59
  aged_client.featured
  now += 2
  begin
    aged_client.featured
    raise "Consumer served expired content during outage"
  rescue Publishing::Unavailable
    puts "Consumer honored Age: 240: cached content survived 59 seconds and failed closed after 61 seconds during injected outage."
  end
else
  puts "HTTP demo: Client HTTPS transport policy is unchanged; use an HTTPS-advertised publisher plus CHECK_PUBLISHER_CONNECT_ORIGIN for the local transport check."
end
