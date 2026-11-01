require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal "downcased@example.com", user.email_address
  end

  test "nickname is limited to twenty characters" do
    user = User.new(nickname: "a" * 21, email_address: "unique@example.com", password: "password")
    assert_not user.valid?
    assert user.errors[:nickname].any?
  end
end
