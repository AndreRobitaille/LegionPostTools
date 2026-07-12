require "test_helper"
require "erb"
require "yaml"

class DatabaseConfigurationTest < ActiveSupport::TestCase
  CONFIG_PATH = Rails.root.join("config/database.yml")
  POSTGRES_ENV_KEYS = %w[POSTGRES_DB POSTGRES_CACHE_DB POSTGRES_QUEUE_DB DB_HOST].freeze

  test "database configuration loads outside production without production postgres env" do
    with_env(POSTGRES_ENV_KEYS.index_with { nil }.merge("RAILS_ENV" => "test")) do
      config = YAML.safe_load(ERB.new(CONFIG_PATH.read).result, aliases: true)

      assert_equal "legion_post_tools_production", config.dig("production", "primary", "database")
      assert_equal "legion_post_tools_production_cache", config.dig("production", "cache", "database")
      assert_equal "legion_post_tools_production_queue", config.dig("production", "queue", "database")
      assert_equal "localhost", config.dig("production", "primary", "host")
    end
  end

  test "database configuration requires production postgres env in production" do
    with_env(POSTGRES_ENV_KEYS.index_with { nil }.merge("RAILS_ENV" => "production")) do
      error = assert_raises(KeyError) do
        ERB.new(CONFIG_PATH.read).result
      end

      assert_includes error.message, "POSTGRES_DB"
    end
  end

  private

  def with_env(values)
    previous = values.keys.to_h { |key| [ key, ENV[key] ] }

    values.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end

    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
