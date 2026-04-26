# frozen_string_literal: true

require "test_helper"

class ModalComponentTest < ViewComponent::TestCase
  test "renders a hidden root with the modal Stimulus controller" do
    render_inline(ModalComponent.new)
    assert_selector "[data-controller='modal'][data-modal-target='root'].hidden", visible: :all
  end

  test "renders an empty turbo-frame named modal as the body slot" do
    render_inline(ModalComponent.new)
    assert_selector "turbo-frame#modal[data-modal-target='frame']", visible: :all
  end

  test "renders a close button with an aria-label" do
    render_inline(ModalComponent.new)
    assert_selector "button[type='button'][aria-label][data-action*='modal#close']", visible: :all
  end

  test "backdrop closes the modal" do
    render_inline(ModalComponent.new)
    assert_selector "[data-action='click->modal#close'].bg-black\\/40", visible: :all
  end
end
