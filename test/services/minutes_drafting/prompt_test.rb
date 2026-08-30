require "test_helper"

class MinutesDrafting::PromptTest < ActiveSupport::TestCase
  test "routes transcript content by agenda subject instead of speaking order" do
    prompt = MinutesDrafting::Prompt::DEVELOPER_PROMPT

    assert_match(/regardless of when it appears in the transcript/, prompt)
    assert_match(/officer report under that officer's matching report item/, prompt)
    assert_match(/use a more specific matching agenda item/, prompt)
    assert_match(/check available_endeavors/, prompt)
    assert_match(/exact endeavor_id/, prompt)
    assert_match(/Good of The American Legion/, prompt)
    assert_match(/Keep citations at the actual transcript\s+lines/, prompt)
  end

  test "requires useful detail while protecting sensitive reports and uncertain identities" do
    prompt = MinutesDrafting::Prompt::DEVELOPER_PROMPT

    assert_match(/member\s+who was absent understand what happened/, prompt)
    assert_match(/significant viewpoints or disagreement/, prompt)
    assert_match(/dates, places, costs, quantities, names, numbers, and statistics/, prompt)
    assert_match(/strict privacy exception to Sick Call and Service Officer reports/, prompt)
    assert_match(/only anonymous or aggregate counts and general\s+activity/, prompt)
    assert_match(/never expand a first name, nickname, or uncertain\s+spelling/, prompt)
  end
end
