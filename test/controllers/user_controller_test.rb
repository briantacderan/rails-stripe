require "test_helper"

class UserControllerTest < ActionDispatch::IntegrationTest
  test "should get Registrations" do
    get user_Registrations_url
    assert_response :success
  end
end
