require "test_helper"

class StripeControllerTest < ActionDispatch::IntegrationTest
  test "should get Checkouts" do
    get stripe_Checkouts_url
    assert_response :success
  end
end
