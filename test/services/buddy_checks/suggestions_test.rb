require "test_helper"
require_relative "../../support/buddy_checks_helpers"

class BuddyChecksSuggestionsTest < ActiveSupport::TestCase
  include BuddyChecksHelpers
  setup { setup_buddy_checks }
  teardown { restore_buddy_configuration }

  test "unknown history offers only identities without manufacturing evidence" do
    excluded = Person.pluck(:id) - [ @member.id, @unassigned.id ]
    result = BuddyChecks::Suggestions.new(mobile_access).suggest(exclude_ids: excluded)
    assert_equal "insufficient_history", result[:state]
    assert_equal "unknown", result.dig(:coverage, :missing_history)
    assert_equal identities(@member, @unassigned), result.fetch(:random_candidates).sort_by { |person| person[:id] }
    assert_not result.key?(:reason)
    assert_not result.key?(:person)
  end

  test "seeded samples are bounded distinct and read only while ranked evidence still wins" do
    people = [ @member, @unassigned ] + (3..6).map { |number| membership_person("Choice#{number}", number) }
    records = -> { [ MembershipContact, BuddyFollowUp, BuddySnooze, MembershipAssignment, BuddyOperation ].map { |model| model.order(:id).map(&:attributes) } }
    assert_no_changes records do
      first = choices_for(*people, seed: 123)
      assert_equal 3, first.size
      assert_equal 3, first.pluck(:id).uniq.size
      assert_empty first.pluck(:id) - people.map(&:id)
      first.each { |identity| assert_equal %i[first_name id last_name], identity.keys.sort }
      assert_equal first, choices_for(*people, seed: 123)
      assert_not_equal first, choices_for(*people, seed: 456)
    end
    operations.record(**buddy_payload(facts: buddy_facts(occurred_at: 100.days.ago.iso8601)))
    result = suggest_only(*people)
    assert_equal "candidate", result[:state]
    assert_equal @member.id, result.dig(:person, :id)
    assert_equal "recorded_contact_is_older", result[:reason]
    assert_not result.key?(:random_candidates)
  end

  test "small pools honor exclusions and exhausted and self-only pools have no choices" do
    assert_equal identities(@member, @unassigned), choices_for(@member, @unassigned).sort_by { |person| person[:id] }
    result = suggest_only(@member, @unassigned, exclude_ids: [ @member.id ])
    assert_equal identities(@unassigned), result[:random_candidates]
    result = suggest_only(@member, @unassigned, exclude_ids: [ @member.id, @unassigned.id ])
    assert_exhausted result
    assert_exhausted suggest_only(@other.person)
  end

  test "selection requires current directory or own assignment access and rejects removed or deceased people" do
    person = membership_person("Hidden", 3)
    person.update!(roster_member_status: "Expired")
    assert_exhausted suggest_only(person)
    @drive.update!(purpose: "buddy_check")
    assignment = @drive.assignments.create!(person:, assigned_to: @other, assigned_by: @officer, expires_on: @drive.ends_on)
    assert_equal identities(person), choices_for(person)
    person.update!(roster_removed_at: Time.current)
    assert_exhausted suggest_only(person)
    person.update!(roster_removed_at: nil, roster_member_status: "Deceased")
    assert_exhausted suggest_only(person)
    person.update!(roster_member_status: "Expired")
    assignment.update!(revoked_at: Time.current)
    assert_exhausted suggest_only(person)
  end

  test "personal hiding expires or can be undone and never hides a person for another caller" do
    receipt = operations.snooze(operation_id: SecureRandom.uuid, person_id: @unassigned.id, until_at: 1.day.from_now.iso8601)
    assert_exhausted suggest_only(@unassigned)
    assert_equal identities(@unassigned), choices_for(@unassigned, user: @volunteer)
    operations.undo_snooze(operation_id: SecureRandom.uuid, id: receipt.dig("snooze", "id"), expected_revision: 0)
    assert_equal identities(@unassigned), choices_for(@unassigned)
    operations.snooze(operation_id: SecureRandom.uuid, person_id: @unassigned.id, until_at: 1.day.from_now.iso8601)
    travel 2.days do
      assert_equal identities(@unassigned), choices_for(@unassigned)
    end
  end

  test "pauses other assignments and recent contact exclude random choices" do
    @drive.update!(purpose: "buddy_check")
    assert_exhausted suggest_only(@member)
    assert_equal identities(@member), choices_for(@member, user: @volunteer)
    workspace.record_contact!(contact_attributes(person_id: @unassigned.id, membership_assignment_id: nil,
      purpose: "buddy_check", channel: "administrative_review", outcome: "do_not_contact", notes: "Synthetic purpose pause"))
    assert_exhausted suggest_only(@unassigned)
    attempt = membership_person("RecentAttempt", 3)
    conversation = membership_person("RecentConversation", 4)
    operations(@volunteer).record(**buddy_payload(person_id: attempt.id, facts: buddy_facts(outcome: "no_answer")))
    operations(@volunteer).record(**buddy_payload(person_id: conversation.id, facts: buddy_facts(occurred_at: 30.days.ago.iso8601)))
    assert_exhausted suggest_only(attempt)
    assert_exhausted suggest_only(conversation)
  end

  test "all open follow-ups exclude random choices including own due callbacks" do
    [ @other, @volunteer ].each_with_index do |owner, index|
      person = membership_person("Callback#{index}", index + 3)
      operations(owner).schedule(operation_id: SecureRandom.uuid, person_id: person.id, due_at: 1.day.from_now.iso8601, entry_zone: "America/Chicago")
      assert_exhausted suggest_only(person)
      travel 2.days do
        assert_exhausted suggest_only(person)
      end
    end
    workspace.record_contact!(contact_attributes(person_id: @unassigned.id, membership_assignment_id: nil,
      purpose: "buddy_check", outcome: "callback_requested", occurred_on: Organization.current_local_date - 14,
      follow_up_on: Organization.current_local_date + 5))
    assert_exhausted suggest_only(@unassigned, user: @officer)
    travel 6.days do
      assert_exhausted suggest_only(@unassigned, user: @officer)
    end
  end

  private

  def suggest_only(*people, user: @other, exclude_ids: [], seed: 123)
    exclusions = (Person.pluck(:id) - people.map(&:id)) | exclude_ids
    BuddyChecks::Suggestions.new(mobile_access(user), random: Random.new(seed)).suggest(exclude_ids: exclusions)
  end

  def choices_for(*people, **options)
    result = suggest_only(*people, **options)
    assert_equal "insufficient_history", result[:state]
    result.fetch(:random_candidates)
  end

  def identities(*people)
    people.sort_by(&:id).map { |person| { id: person.id, first_name: person.first_name, last_name: person.last_name } }
  end

  def assert_exhausted(result)
    assert_equal "exhausted", result[:state]
    assert_empty result.fetch(:random_candidates, [])
  end
end
