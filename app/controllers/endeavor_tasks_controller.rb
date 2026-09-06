class EndeavorTasksController < ApplicationController
  before_action -> { require_capability("manage_agendas") }
  before_action :set_endeavor
  before_action :set_task, only: %i[edit update]

  def new
    @task = @endeavor.tasks.new
  end

  def create
    @task = @endeavor.tasks.new(task_params.except(:lock_version))
    @task.created_by = current_user
    save_task(:new)
  end

  def edit; end

  def update
    @task.assign_attributes(task_params)
    if params[:endeavor_task].key?(:completed)
      @task.set_completion(ActiveModel::Type::Boolean.new.cast(params[:endeavor_task][:completed]), user: current_user)
    end
    save_task(:edit)
  rescue ActiveRecord::StaleObjectError
    redirect_to endeavor_path(@endeavor, anchor: "endeavor-next-steps"), alert: "This next step changed elsewhere. Review the latest details before saving again."
  end

  private

  def set_endeavor
    @endeavor = Organization.first!.endeavors.find(params[:endeavor_id])
  end

  def set_task
    @task = @endeavor.tasks.find(params[:id])
  end

  def task_params
    params.require(:endeavor_task).permit(:title, :due_on, :lock_version)
  end

  def save_task(template)
    @task.updated_by = current_user
    raw = params[:endeavor_task][:due_on]
    date = helpers.parse_legion_date(raw)
    @task.due_on = date if params[:endeavor_task].key?(:due_on)
    valid = @task.valid?
    invalid_date = raw.present? && date.nil?
    @task.errors.add(:due_on, "must be a date such as 15 SEP 2026") if invalid_date
    if valid && !invalid_date && @task.save
      redirect_to endeavor_path(@endeavor, anchor: "endeavor-next-steps"), notice: "Next step saved."
    else
      render template, status: :unprocessable_entity
    end
  end
end
