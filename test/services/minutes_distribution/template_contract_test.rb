require "test_helper"
require_relative "../../support/minutes_distribution_provider"
require_relative "../../support/minutes_distribution_data"

class MinutesDistributionTemplateContractTest < ActiveSupport::TestCase
  include MinutesDistributionData
  setup { setup_distribution }

  test "versioned provider template is well formed and all its variables are supplied" do
    source = Rails.root.join("emails/minutes-v2.lmx").read
    metadata = JSON.parse(Rails.root.join("emails/minutes-v2.json").read)
    document = Nokogiri::XML("<Email>#{source}</Email>") { |config| config.strict.nonet }
    dispatch(attest)
    variables = provider.messages.sole.fetch(:dataVariables)
    required = [ source, metadata.to_json ].join.scan(/\{data\.([a-z_]+)\}/).flatten.uniq
    assert_empty required - variables.keys
    assert_equal "styled", metadata.fetch("emailFormat")
    assert_equal "", metadata.fetch("dataVariablesFallbacks").fetch("correction_notice")
    assert_equal 1, document.css("Style").size
    assert_equal "18", document.at_css("Style")["textBaseFontSize"]
    assert_equal "Minutes PDF attached", document.at_css("Section H2").text
    assert_empty document.css("Button, Link, Image")
    assert_equal "{data.correction_notice}", document.at_css("Section[if]")["if"]
    assert_empty metadata.keys & %w[ccEmail bccEmail]
  end
end
