class CardComponent < ViewComponent::Base
  def initialize(**system_arguments)
    @system_arguments = system_arguments
  end
end
