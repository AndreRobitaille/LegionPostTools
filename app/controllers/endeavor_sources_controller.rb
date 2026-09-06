class EndeavorSourcesController < ApplicationController
  before_action :require_authentication
  rescue_from ActiveRecord::RecordNotFound, with: :source_unavailable

  def show
    @endeavor = Organization.first!.endeavors.find(params[:id])
    @source = EndeavorHistory::Presenter.new(@endeavor).source(
      revision_id: params[:revision_id], record_key: params[:record_key], unit_ids: params[:unit_ids])
    response.headers["Cache-Control"] = "private, no-store"
  end
  private

  def source_unavailable
    response.headers["Cache-Control"] = "private, no-store"
    render :unavailable, status: :not_found
  end
end
