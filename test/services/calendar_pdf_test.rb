require "test_helper"

class CalendarPdfTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Example Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @month = CalendarMonth.new(organization: @organization, date: Date.new(2026, 9, 12), view: "public", categories: %w[honor_guard public_event])
  end

  test "filename identifies the selected month and view" do
    assert_equal "calendar-2026-09-public.pdf", CalendarPdf.filename(month: @month)
  end

  test "signed token binds the organization month view and categories" do
    assert_equal({ "organization_id" => @organization.id, "date" => "2026-09-01", "view" => "public",
      "categories" => %w[honor_guard public_event] }, CalendarPdf.verify_source_token!(token))
  end

  test "render uses the bounded browser renderer and a signed loopback source" do
    rendered = {}
    renderer = lambda do |source_url:, temp_prefix:|
      rendered.merge!(source_url: source_url, temp_prefix: temp_prefix)
      "%PDF-calendar"
    end
    original = BrowserPdfRenderer.method(:render)
    BrowserPdfRenderer.define_singleton_method(:render, renderer)
    assert_equal "%PDF-calendar", CalendarPdf.render(organization: @organization, month: @month, base_url: "http://127.0.0.1:4321/")
    uri = URI(rendered.fetch(:source_url))
    assert_equal "http://127.0.0.1:4321/internal/calendar-pdf-source", "#{uri.scheme}://#{uri.host}:#{uri.port}#{uri.path}"
    payload = CalendarPdf.verify_source_token!(URI.decode_www_form(uri.query).to_h.fetch("token"))
    assert_equal "2026-09-01", payload.fetch("date")
    assert_equal "calendar-pdf", rendered.fetch(:temp_prefix)
  ensure
    BrowserPdfRenderer.define_singleton_method(:render, original)
  end

  test "tokens expire after one minute" do
    source_token = token
    travel 61.seconds do
      assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) { CalendarPdf.verify_source_token!(source_token) }
    end
  end

  test "signed but invalid selections fail closed" do
    payload = CalendarPdf.verify_source_token!(token)
    [ { "date" => "2026-09-12" }, { "date" => "2201-01-01" }, { "date" => "not-a-date" },
      { "view" => "officer_notes" }, { "categories" => [ "unknown" ] }, { "categories" => "honor_guard" } ].each do |change|
      invalid = Rails.application.message_verifier("calendar-pdf-source").generate(payload.merge(change))
      assert_raises(ArgumentError) { CalendarPdf.verify_source_token!(invalid) }
    end
  end

  private

  def token
    CalendarPdf.source_token(organization: @organization, month: @month)
  end
end
