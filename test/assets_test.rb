require "test_helper"

class AssetsTest < ActiveSupport::TestCase
  test "the American Legion emblem asset is available" do
    path = ActionController::Base.helpers.image_path("al-emblem.png")
    assert path.present?, "al-emblem.png should resolve to an asset path"
  end
end
