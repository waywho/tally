class ListRowComponent < ViewComponent::Base
  def initialize(label:, value:, **system_arguments)
    @label = label
    @value = value
    @system_arguments = system_arguments
  end
end
