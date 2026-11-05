require "test_helper"
require_relative "../../../script/support/endeavor_history_comparison"
require_relative "../../support/shared_endeavor_history_provider"

class EndeavorHistoryComparisonTest < ActiveSupport::TestCase
  test "comparison uses production stages without reading or writing the database" do
    source = { "revision_id" => 1, "sha256" => "synthetic", "items" => [
      { "key" => "one", "title" => "Finance report", "units" => [ { "id" => "one:body", "kind" => "body", "text" => "Both events received $100." } ] }
    ] }
    targets = %w[Car\ Show Picnic].each_with_index.map do |title, i|
      { "id" => i + 1, "title" => title, "summary" => "Synthetic", "guidance" => "", "generation" => 0 }
    end
    snapshot = { "targets" => targets, "catalog" => targets, "documents" => [ source ] }
    provider = SharedEndeavorHistoryTestProvider.new
    shared = {}
    sql = []
    callback = ->(*args) { sql << args.last[:sql] }
    results = ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      targets.map { |target| EndeavorHistoryComparison::Pipeline.new(snapshot: snapshot, target: target, provider: provider, shared: shared).call }
    end
    assert_empty sql
    assert_equal %w[shared_discovery verify_shared_discovery summary verify_summary summary verify_summary], provider.calls.map(&:first)
    assert results.all? { |result| result["evidence"].first["facts"].first["text"].include?("$100") }
  end

  test "budget is durable before dispatch and unknown failure cannot release it or change ceiling" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "ledger.json")
      ledger = EndeavorHistoryComparison::Ledger.new(path: path, ceiling: "1.3")
      params = { model: "gpt-6-astra", input: "synthetic", max_output_tokens: 24_000, prompt_cache_options: { mode: :explicit } }
      calls = 0
      transport = Object.new
      transport.define_singleton_method(:create) do |**_params|
        calls += 1
        raise "Reservation not saved" unless JSON.parse(File.read(path))["steps"].first["reserved"]
        raise EndeavorHistory::Error, "timeout"
      end
      assert_raises(EndeavorHistory::Error) { ledger.call(transport, params) }
      assert ledger.state["steps"].first["reserved"]
      assert_operator ledger.charged, :>, 1.2
      ledger.close
      ledger = EndeavorHistoryComparison::Ledger.new(path: path, ceiling: "1.3")
      assert_equal "evaluation_budget", assert_raises(EndeavorHistory::Error) { ledger.call(transport, params) }.category
      assert_equal 1, calls
      assert_equal 0600, File.stat(path).mode & 0777
      ledger.close
      assert_raises(RuntimeError) { EndeavorHistoryComparison::Ledger.new(path: path, ceiling: "2") }
    ensure
      ledger&.close
    end
  end

  test "incomplete provider responses still record their measured usage and standard service tier" do
    Dir.mktmpdir do |directory|
      ledger = EndeavorHistoryComparison::Ledger.new(path: File.join(directory, "ledger.json"), ceiling: "2")
      response = OpenAI::Models::Responses::Response.new(id: "resp_synthetic", status: :incomplete,
        usage: OpenAI::Models::Responses::ResponseUsage.new(input_tokens: 100, output_tokens: 20, total_tokens: 120,
          input_tokens_details: OpenAI::Models::Responses::ResponseUsage::InputTokensDetails.new(cached_tokens: 10, cache_write_tokens: 0)))
      def response._request_id = "req_synthetic"
      transport = Object.new
      received = nil
      transport.define_singleton_method(:create) { |**params| received = params; response }
      ledger.call(transport, model: "gpt-6-astra", input: "synthetic", max_output_tokens: 24_000, prompt_cache_options: { mode: :explicit })
      assert_equal :default, received[:service_tier]
      assert_not ledger.state["steps"].first["reserved"]
      assert_equal BigDecimal("0.00191"), ledger.charged
    ensure
      ledger&.close
    end
  end
end
