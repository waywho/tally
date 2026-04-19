class CardComponentPreview < Lookbook::Preview
  # @label Default card
  def default
    render CardComponent.new do
      tag.div(class: "p-4") do
        tag.h3("Breakfast", class: "font-semibold text-text") +
        tag.p("3 items logged", class: "text-sm text-text-secondary mt-1")
      end
    end
  end
end
