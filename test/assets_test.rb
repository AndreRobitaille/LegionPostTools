require "test_helper"

class AssetsTest < ActiveSupport::TestCase
  test "the American Legion emblem asset is available" do
    path = ActionController::Base.helpers.image_path("al-emblem.png")
    assert path.present?, "al-emblem.png should resolve to an asset path"
  end

  test "print pagination does not chain title-only agenda items" do
    print_css = Rails.root.join("app/assets/tailwind/application.css").read.split("@media print", 2).last
    title_rule = print_css.match(/\.agenda-item-title\s*\{(?<declarations>[^}]*)\}/)[:declarations]

    assert_no_match(/break-after/, title_rule)
    assert_match(
      /\.agenda-item-title:not\(:last-child\)\s*\{[^}]*break-after:\s*avoid;/,
      print_css
    )
  end
end
