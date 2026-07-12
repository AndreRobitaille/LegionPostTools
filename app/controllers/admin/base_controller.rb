module Admin
  class BaseController < ApplicationController
    before_action -> { require_capability("manage_settings") }
  end
end
