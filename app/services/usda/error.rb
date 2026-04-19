module Usda
  class Error < StandardError; end

  class ConfigError < Error; end

  class ApiError < Error
    attr_reader :status_code

    def initialize(message, status_code: nil)
      @status_code = status_code
      super(message)
    end
  end

  class RateLimitError < ApiError
    def initialize(message = "USDA API rate limit exceeded (1,000 requests/hour)")
      super(message, status_code: 429)
    end
  end
end
