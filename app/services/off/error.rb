module Off
  class Error < StandardError; end

  class ApiError < Error; end

  class ProductNotFoundError < Error
    def initialize(barcode)
      super("Product not found: #{barcode}")
    end
  end
end
