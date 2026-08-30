require "test_helper"

class OrganizationTest < ActiveSupport::TestCase
  test "normalizes and validates the public document email" do
    organization = Organization.new(
      name: "Test Post",
      unit_type: "american_legion_post",
      timezone: "America/Chicago",
      public_email: " POST@EXAMPLE.ORG "
    )

    assert organization.valid?
    assert_equal "post@example.org", organization.public_email

    organization.public_email = "not an email"

    assert_not organization.valid?
    assert_includes organization.errors[:public_email], "is invalid"
  end

  test "limits the printed mailing address to two nonblank lines" do
    organization = Organization.new(
      name: "Test Post",
      unit_type: "american_legion_post",
      timezone: "America/Chicago",
      mailing_address: "P.O. Box 11\n\nTwo Rivers, WI 54241"
    )

    assert organization.valid?
    assert_equal [ "P.O. Box 11", "Two Rivers, WI 54241" ], organization.mailing_address_lines

    organization.mailing_address = "Post 165\nP.O. Box 11\nTwo Rivers, WI 54241"

    assert_not organization.valid?
    assert_includes organization.errors[:mailing_address], "must fit on no more than two lines"
  end
end
