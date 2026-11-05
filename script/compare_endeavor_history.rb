# Explicitly authorized live calls only. No database or published-history writes.
# RAILS_ENV=test bin/rails runner script/compare_endeavor_history.rb SNAPSHOT LEDGER CEILING LABEL shared|baseline
require_relative "support/endeavor_history_comparison"

abort "Usage: SNAPSHOT LEDGER CEILING LABEL shared|baseline" unless ARGV.size == 5
abort "Set ENDEAVOR_EVALUATION_AUTHORIZED=1 after explicit authorization" unless ENV["ENDEAVOR_EVALUATION_AUTHORIZED"] == "1"
abort "Use the test environment" unless Rails.env.test?
abort "Use the standard OpenAI endpoint" if ENV["OPENAI_BASE_URL"].present? || ENV["OPENAI_DATA_RESIDENCY"].present?
snapshot_path, ledger_path, ceiling, label, mode = ARGV
$stdout.sync = true
ledger = EndeavorHistoryComparison::Ledger.new(path: ledger_path, ceiling: ceiling)
begin
  EndeavorHistoryComparison.run(snapshot: JSON.parse(File.read(snapshot_path)), ledger: ledger, label: label, mode: mode)
ensure
  ledger.close
end
