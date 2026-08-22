class CreateAgentApiExecutions < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_api_executions do |t|
      t.references :agent_access_token, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :idempotency_key, null: false
      t.string :request_method, null: false
      t.string :request_path, null: false
      t.string :request_fingerprint, null: false
      t.string :state, default: "processing", null: false
      t.integer :response_status
      t.text :response_body

      t.timestamps
    end

    add_index :agent_api_executions,
      %i[agent_access_token_id idempotency_key],
      unique: true,
      name: "idx_agent_api_executions_token_key"
    add_index :agent_api_executions, %i[state created_at]
    add_check_constraint :agent_api_executions,
      "state IN ('processing', 'completed')",
      name: "agent_api_executions_state_check"
  end
end
