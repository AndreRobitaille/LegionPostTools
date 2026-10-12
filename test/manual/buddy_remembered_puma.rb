raise "Dedicated remembered integration required" unless ENV["BUDDY_MOBILE_INTEGRATION"] == "true" &&
  ENV["DATABASE_URL"] == "postgresql:///legion_buddy_remembered_test" && ENV["MOBILE_BUDDY_CHECK_ISSUER"] == "https://192.168.37.41:3446"
environment "test"
threads 1, 4
workers 0
ssl_bind "0.0.0.0", 3446, key: ENV.fetch("BUDDY_MOBILE_TLS_KEY"), cert: ENV.fetch("BUDDY_MOBILE_TLS_CERT"), no_tlsv1_1: true
pidfile ENV.fetch("BUDDY_MOBILE_PID_FILE")
rackup File.expand_path("../../config.ru", __dir__)
