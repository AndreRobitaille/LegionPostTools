require "test_helper"
require_relative "../support/minutes_distribution_provider"
require_relative "../support/minutes_distribution_data"

class MinutesDistributionPdfTest < ActionDispatch::IntegrationTest
  include MinutesDistributionData
  setup { setup_distribution }

  test "distribution source preserves the exact original copy and closing authority after later corrections" do
    issue = attest
    dispatch(issue)
    token = MeetingMinutesPdf.distribution_source_token(issue:)
    original = issue.minutes_revision.attributes
    newer = correct("Balance: $103.")
    organization.update!(name: "Changed live letterhead")
    get meeting_minutes_pdf_source_path(token:)
    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_includes response.headers.fetch("Content-Security-Policy"), "default-src 'none'"
    assert_select ".agenda-org-name", text: "Synthetic Legion Post"
    assert_select ".minutes-doc-narrative", text: /Balance: \$100/
    assert_select ".minutes-doc-narrative", text: /103/, count: 0
    assert_select ".minutes-authority-folio", text: /Record of authority.*Attested.*Awaiting action.*Immutable revision 1/m
    assert_equal original, issue.minutes_revision.reload.attributes
    get meeting_minutes_pdf_source_path(token: MeetingMinutesPdf.source_token(minutes:, revision: issue.minutes_revision))
    assert_response :not_found, "The ordinary member source still rejects superseded revisions"
    dispatch(newer)
    approve
    get meeting_minutes_pdf_source_path(token: MeetingMinutesPdf.distribution_source_token(issue: newer.reload))
    assert_response :success
    assert_select ".minutes-authority-folio", text: /Awaiting action/, count: 1
    assert_select ".minutes-doc-narrative", text: /103/
  end

  test "approved corrected source uses captured meeting decision and original status" do
    dispatch(attest)
    approve(corrections_pending: true)
    @item.update!(body: "Balance: $101.")
    issue = attest
    dispatch(issue)
    get meeting_minutes_pdf_source_path(token: MeetingMinutesPdf.distribution_source_token(issue:))
    assert_response :success
    assert_select ".minutes-doc-status-label", text: "Official - approved and locked"
    assert_select ".minutes-authority-folio", text: /Meeting approval.*Approved as corrected/m
    assert_select ".minutes-authority-folio", text: /Attested.*Synthetic Adjutant/m
  end

  test "distribution source rejects expired invalid cross-record and non-loopback requests" do
    issue = attest
    dispatch(issue)
    token = MeetingMinutesPdf.distribution_source_token(issue:)
    get meeting_minutes_pdf_source_path(token:), headers: { "REMOTE_ADDR" => "203.0.113.8" }
    assert_response :not_found
    travel 2.minutes do
      get meeting_minutes_pdf_source_path(token:)
      assert_response :not_found
    end
    get meeting_minutes_pdf_source_path(token: "invalid")
    assert_response :not_found
    payload = MeetingMinutesPdf.verify_source_token!(token).merge("meeting_minutes_id" => -1)
    wrong_record = Rails.application.message_verifier("meeting-minutes-pdf-source").generate(payload, expires_in: 1.minute)
    get meeting_minutes_pdf_source_path(token: wrong_record)
    assert_response :not_found
  end
end
