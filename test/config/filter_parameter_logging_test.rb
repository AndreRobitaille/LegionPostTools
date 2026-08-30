require "test_helper"

class FilterParameterLoggingTest < ActiveSupport::TestCase
  test "filters the complete meeting transcript parameter" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    parameters = {
      "meeting_transcript" => {
        "pasted_text" => "Commander: private source words",
        "retention_policy" => "delete_after_acceptance"
      }
    }

    assert_equal "[FILTERED]", filter.filter(parameters)["meeting_transcript"]
  end

  test "filters transcript content even outside the expected form nesting" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    assert_equal "[FILTERED]", filter.filter("transcript_content" => "private source words")["transcript_content"]
    assert_equal "[FILTERED]", filter.filter("pasted_text" => "private source words")["pasted_text"]
  end
end
