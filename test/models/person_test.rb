require "test_helper"

class PersonTest < ActiveSupport::TestCase
  test "full_name joins first and last name" do
    person = Person.new(first_name: "Jane", last_name: "Doe")

    assert_equal "Jane Doe", person.full_name
  end

  test "requires first_name and last_name" do
    person = Person.new

    assert_not person.valid?
    assert_includes person.errors[:first_name], "can't be blank"
    assert_includes person.errors[:last_name], "can't be blank"
  end
end
