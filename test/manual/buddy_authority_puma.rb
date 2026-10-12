require "uri"
raise "Integration mode required" unless ENV["BUDDY_MOBILE_INTEGRATION"] == "true"
origin = URI(ENV.fetch("MOBILE_BUDDY_CHECK_ISSUER"))
raise "Dedicated authority port required" unless origin.scheme == "https" && [ 3444, 3445 ].include?(origin.port)
environment "test"
threads 1, 4
workers 0
ssl_bind "0.0.0.0", origin.port, key: ENV.fetch("BUDDY_MOBILE_TLS_KEY"), cert: ENV.fetch("BUDDY_MOBILE_TLS_CERT"), no_tlsv1_1: true
pidfile ENV.fetch("BUDDY_MOBILE_PID_FILE")
rackup File.expand_path("../../config.ru", __dir__)
