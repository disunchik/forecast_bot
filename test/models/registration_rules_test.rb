require "test_helper"

class RegistrationRulesTest < ActiveSupport::TestCase
  def account(**attrs)
    User.new({ nickname: "Новый_Фан-1", email_address: "newfan@example.com", password: "password1", password_confirmation: "password1" }.merge(attrs))
  end

  test "new accounts enforce displayed nickname and password rules" do
    [ "a", "a" * 21, "@oldfan", "fan.name", "fan/../" ].each do |nickname|
      assert_not account(nickname: nickname).valid?, nickname
    end
    [ "a", "1234567", "a" * 73 ].each do |password|
      assert_not account(password: password, password_confirmation: password).valid?
    end
    assert_not account(password_confirmation: "different").valid?
    assert account(nickname: "ab").valid?
    assert account(nickname: "Я" * 20).valid?
  end

  test "new nicknames are unique regardless of case and surrounding spaces" do
    account.save!
    duplicate = account(nickname: "  НОВЫЙ_ФАН-1  ", email_address: "otherfan@example.com")
    assert_not duplicate.valid?
  end
end
