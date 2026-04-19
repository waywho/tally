import { Controller } from "@hotwired/stimulus"

// Syncs a range input (slider) with a number input bidirectionally.
// Usage:
//   <div data-controller="slider-sync">
//     <input type="range" data-slider-sync-target="slider" data-action="input->slider-sync#syncFromSlider">
//     <input type="number" data-slider-sync-target="number" data-action="input->slider-sync#syncFromNumber">
//   </div>
export default class extends Controller {
  static targets = ["slider", "number"]

  syncFromSlider() {
    this.numberTarget.value = this.sliderTarget.value
  }

  syncFromNumber() {
    this.sliderTarget.value = this.numberTarget.value
  }
}
