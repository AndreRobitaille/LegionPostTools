module Api
  class EndeavorTasksController < BaseController
    include Concerns::ActivityContract
    before_action -> { require_capability("manage_agendas") }, only: %i[create update]
    before_action :set_endeavor
    before_action :set_task, only: %i[show update]

    def index
      scope = @endeavor.tasks.ordered
      if params.key?(:status)
        raise ArgumentError, "status must be open or completed." unless %w[open completed].include?(params[:status])
        scope = params[:status] == "open" ? scope.open : scope.completed
      end
      page = collection_page(scope)
      return unless page

      render json: { tasks: page[:records].map { |task| endeavor_task_payload(task) }, pagination: page[:metadata] }
    end

    def show
      render json: { task: endeavor_task_payload(@task) }
    end

    def create
      @task = @endeavor.tasks.new(task_attributes)
      @task.created_by = @task.updated_by = current_user
      @task.save!
      render json: { task: endeavor_task_payload(@task) }, status: :created
    end

    def update
      @task.lock_version = activity_lock_version!(@task)
      @task.assign_attributes(task_attributes)
      @task.set_completion(activity_boolean(:completed), user: current_user) if params.key?(:completed)
      @task.updated_by = current_user
      @task.save!
      render json: { task: endeavor_task_payload(@task) }
    end

    private

    def set_endeavor
      @endeavor = organization.endeavors.find(params[:endeavor_id])
    end

    def set_task
      @task = @endeavor.tasks.find(params[:id])
    end

    def task_attributes
      attributes = params.permit(:title)
      attributes[:due_on] = activity_date(params[:due_on], field: :due_on) if params.key?(:due_on)
      attributes
    end
  end
end
