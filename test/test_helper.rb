ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    include FactoryBot::Syntax::Methods

    # FoodSearch queries USDA on every search (USDA isn't cached locally).
    # Stub it to an empty response by default so tests that don't mock the
    # client explicitly don't hit the real API. Tests can override with their
    # own WebMock stub or by injecting a mock client.
    setup do
      WebMock.stub_request(:post, %r{api\.nal\.usda\.gov/fdc/v1/foods/search})
        .to_return(
          status: 200,
          body: '{"foods":[]}',
          headers: { "Content-Type" => "application/json" }
        )
    end

    # Add more helper methods to be used by all tests here...
  end
end
