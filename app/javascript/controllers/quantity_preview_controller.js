import { Controller } from "@hotwired/stimulus"

// Live calorie/macro preview as user types grams.
// Reads per-100g values from the panel's data attributes.
// Usage:
//   <div data-controller="quantity-preview"
//        data-quantity-preview-calories-per100-value="250"
//        data-quantity-preview-protein-per100-value="10"
//        ...>
//     <input data-quantity-preview-target="input" data-action="input->quantity-preview#update">
//     <span data-quantity-preview-target="calories">0</span>
//     <span data-quantity-preview-target="protein">0</span>
//     ...
//   </div>
export default class extends Controller {
  static targets = ["input", "calories", "protein", "carbs", "fat", "fiber"]
  static values = {
    caloriesPer100: { type: Number, default: 0 },
    proteinPer100: { type: Number, default: 0 },
    carbsPer100: { type: Number, default: 0 },
    fatPer100: { type: Number, default: 0 },
    fiberPer100: { type: Number, default: 0 }
  }

  update() {
    const grams = parseFloat(this.inputTarget.value) || 0
    const factor = grams / 100

    this.caloriesTarget.textContent = Math.round(this.caloriesPer100Value * factor)
    this.proteinTarget.textContent = (this.proteinPer100Value * factor).toFixed(1)
    this.carbsTarget.textContent = (this.carbsPer100Value * factor).toFixed(1)
    this.fatTarget.textContent = (this.fatPer100Value * factor).toFixed(1)
    this.fiberTarget.textContent = (this.fiberPer100Value * factor).toFixed(1)
  }
}
