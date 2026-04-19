class ButtonComponent < ViewComponent::Base
  SCHEMES = {
    primary: "bg-primary text-white hover:bg-primary-light",
    secondary: "bg-white text-primary border border-primary hover:bg-primary-tint"
  }.freeze

  SIZES = {
    sm: "px-3 py-1.5 text-sm",
    md: "px-4 py-2.5 text-base"
  }.freeze

  def initialize(label:, scheme: :primary, size: :md, tag: :button, **system_arguments)
    @label = label
    @scheme = scheme
    @size = size
    @tag = tag
    @system_arguments = system_arguments
  end

  def call
    content_tag(
      @tag,
      @label,
      class: class_names,
      **@system_arguments
    )
  end

  private

  def class_names
    [
      "inline-flex items-center justify-center font-semibold rounded-md transition-colors cursor-pointer",
      SCHEMES.fetch(@scheme),
      SIZES.fetch(@size)
    ].join(" ")
  end
end
