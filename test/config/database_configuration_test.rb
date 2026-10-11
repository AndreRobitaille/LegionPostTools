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
    values = production_values
    POSTGRES_ENV_KEYS.each do |missing_key|
      with_env(values.merge(missing_key => nil)) do
        error = assert_raises(KeyError, "Missing #{missing_key} must refuse production configuration") do
          ERB.new(CONFIG_PATH.read).result
        end

        assert_includes error.message, missing_key
      end
    end
  end

  test "supplied production database identities and host are preserved" do
    with_env(production_values) do
      config = YAML.safe_load(ERB.new(CONFIG_PATH.read).result, aliases: true)
      assert_equal "synthetic_primary", config.dig("production", "primary", "database")
      assert_equal "synthetic_cache", config.dig("production", "cache", "database")
      assert_equal "synthetic_queue", config.dig("production", "queue", "database")
      %w[primary cache queue].each do |connection|
        assert_equal "synthetic-db.example.test", config.dig("production", connection, "host")
      end
    end
  end

  test "database configuration loads during production asset precompile with dummy secret" do
    with_env(POSTGRES_ENV_KEYS.index_with { nil }.merge("RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1")) do
      config = YAML.safe_load(ERB.new(CONFIG_PATH.read).result, aliases: true)

      assert_equal "legion_post_tools_production", config.dig("production", "primary", "database")
      assert_equal "localhost", config.dig("production", "primary", "host")
    end
  end

  private

  def production_values
    { "RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => nil,
      "POSTGRES_DB" => "synthetic_primary", "POSTGRES_CACHE_DB" => "synthetic_cache",
      "POSTGRES_QUEUE_DB" => "synthetic_queue", "DB_HOST" => "synthetic-db.example.test" }
  end

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
