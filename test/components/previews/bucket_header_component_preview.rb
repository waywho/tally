class BucketHeaderComponentPreview < Lookbook::Preview
  # @label Breakfast with entries
  def with_entries
    render_with_template
  end

  # @label Empty bucket
  def empty
    render BucketHeaderComponent.new(meal: "Snacks", subtotal: 0, add_path: "#")
  end
end
