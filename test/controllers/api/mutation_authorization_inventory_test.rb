require "test_helper"

class ApiMutationAuthorizationInventoryTest < ActiveSupport::TestCase
  test "every routed API mutation has a current authority guard for completed retries" do
    mutations = Rails.application.routes.routes.select do |route|
      route.defaults[:controller].to_s.start_with?("api/") && route.verb.match?(/POST|PATCH|PUT|DELETE/)
    end
    assert mutations.any?, "The mutation route inventory must not silently become empty."
    unguarded = mutations.filter_map do |route|
      controller = "#{route.defaults[:controller].camelize}Controller".constantize
      action = route.defaults[:action]
      guarded = controller.api_authorization_callbacks.any? do |check|
        (check[:only].nil? || check[:only].include?(action)) && !check[:except].include?(action)
      end
      "#{route.verb} #{route.path.spec}" unless guarded
    end
    assert_empty unguarded, "These mutation actions would have no replay authority check: #{unguarded.join(', ')}"
  end
end
