require "test_helper"

class Api::V1::PathConfigurationsControllerTest < ActionDispatch::IntegrationTest
  test "returns path configuration JSON without authentication" do
    get "/api/v1/path_configuration.json"
    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("settings")
    assert json.key?("rules")
    assert_equal "application/json", response.media_type
  end
end
