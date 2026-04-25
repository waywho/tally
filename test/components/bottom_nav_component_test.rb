# frozen_string_literal: true

require "test_helper"

class BottomNavComponentTest < ViewComponent::TestCase
  test "renders all five slots" do
    render_inline(BottomNavComponent.new(current_path: "/today"))
    assert_selector "a[aria-label='Today']"
    assert_selector "a[aria-label='Search']"
    assert_selector "a[aria-label='Add food']"
    assert_selector "a[aria-label='Recipes']"
    assert_selector "a[aria-label='Settings']"
  end

  test "marks Today active on /today" do
    render_inline(BottomNavComponent.new(current_path: "/today"))
    assert_selector "a[aria-label='Today'][aria-current='page']"
  end

  test "marks Today active on /days/:date" do
    render_inline(BottomNavComponent.new(current_path: "/days/2026-04-25"))
    assert_selector "a[aria-label='Today'][aria-current='page']"
  end

  test "marks Recipes active on /recipes" do
    render_inline(BottomNavComponent.new(current_path: "/recipes"))
    assert_selector "a[aria-label='Recipes'][aria-current='page']"
  end

  test "marks Settings active on /settings/edit" do
    render_inline(BottomNavComponent.new(current_path: "/settings/edit"))
    assert_selector "a[aria-label='Settings'][aria-current='page']"
  end

  test "add button uses inferred meal and viewed date" do
    travel_to Time.zone.local(2026, 4, 25, 12, 0) do
      render_inline(BottomNavComponent.new(current_path: "/today", viewed_date: Date.new(2026, 4, 20)))
      assert_selector "a[aria-label='Add food'][href*='meal=lunch'][href*='date=2026-04-20']"
    end
  end

  test "add button defaults to today when viewed_date is nil" do
    travel_to Time.zone.local(2026, 4, 25, 8, 0) do
      render_inline(BottomNavComponent.new(current_path: "/recipes"))
      assert_selector "a[aria-label='Add food'][href*='meal=breakfast'][href*='date=2026-04-25']"
    end
  end
end
