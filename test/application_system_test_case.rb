require "test_helper"

# Base class for browser-driven (system) tests.
#
# These run a real headless Chromium against a Puma server Capybara boots on
# 127.0.0.1 in the TEST environment against the ephemeral test database. That
# means:
#   * Nothing binds to the LAN and no production config, DB, or secrets are
#     touched — this cannot affect production.
#   * The server runs on localhost, which is a secure context, so passkeys /
#     WebAuthn would work here if ever needed (unlike http over the LAN IP).
#   * Sign-in uses the app's REAL magic-link path (see #system_sign_in) — no
#     passkey ceremony and no test-only auth backdoor.
#
# System tests do NOT run as part of `bin/rails test`; run them explicitly with
# `bin/rails test:system` (or `bin/rails test:all`).
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # One browser at a time. System suites are small, and a single Chromium avoids
  # spawning one instance per CPU core (the parent class enables parallelism).
  parallelize(workers: 1)

  # Drive headless Chromium using the browser and driver already installed on
  # the box. Pinning both binaries stops Selenium Manager from reaching out to
  # download anything, so the suite runs fully offline.
  Capybara.register_driver :headless_chromium do |app|
    options = Selenium::WebDriver::Chrome::Options.new
    options.binary = ENV.fetch("CHROMIUM_BIN", "/usr/bin/chromium")
    options.add_argument("--headless=new")
    options.add_argument("--disable-gpu")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--window-size=1400,1400")

    service = Selenium::WebDriver::Service.chrome(path: ENV.fetch("CHROMEDRIVER_BIN", "/usr/bin/chromedriver"))
    Capybara::Selenium::Driver.new(app, browser: :chrome, options: options, service: service)
  end

  driven_by :headless_chromium

  # Sign in through the app's real magic-link flow: mint a link for the user,
  # open it (GET renders the confirmation screen), then click through to POST
  # and establish the session. No production code is bypassed.
  def system_sign_in(user)
    magic_link = MagicLink.create_for!(user)
    visit magic_link_session_path(token: magic_link.token)
    click_button "Finish signing in"
    # Wait for the sign-in POST + redirect to finish before returning, so the
    # session cookie is set before the caller navigates away. "Sign out" only
    # appears in the authenticated nav.
    assert_text "Sign out"
  end
end
