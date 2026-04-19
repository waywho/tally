class BucketHeaderComponentPreview < Lookbook::Preview
  # @label Breakfast with entries
  def with_entries
    render_with_template(template: "bucket_header_component_preview/with_entries")
  end

  # @label Empty bucket
  def empty
    render BucketHeaderComponent.new(meal: "Snacks", subtotal: 0, add_path: "#")
  end
end
