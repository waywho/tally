class ListRowComponentPreview < Lookbook::Preview
  # @label Food items in a card
  def default
    render_with_template(template: "list_row_component_preview/default")
  end
end
