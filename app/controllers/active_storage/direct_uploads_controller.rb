# Lexxy needs the engine's URL helpers even when attachments are disabled.
# Supported transcript and roster uploads attach files through authorized app controllers.
class ActiveStorage::DirectUploadsController < ActiveStorage::BaseController
  def create
    head :not_found
  end
end
