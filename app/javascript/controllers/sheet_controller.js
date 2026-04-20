import { Controller } from "@hotwired/stimulus"

// Manages a bottom sheet overlay.
// Usage:
//   <div data-controller="sheet">
//     <button data-action="click->sheet#open" data-sheet-name-param="Chicken" ...>
//     <div data-sheet-target="overlay" class="hidden">
//       <div data-sheet-target="panel">...</div>
//     </div>
//   </div>
export default class extends Controller {
  static targets = ["overlay", "panel", "foodName", "foodCalories", "foodProtein", "foodCarbs", "foodFat", "foodFiber", "foodIdField", "usdaFdcIdField", "usdaNameField", "usdaCaloriesField", "usdaProteinField", "usdaCarbsField", "usdaFatField", "usdaFiberField"]

  open(event) {
    event.preventDefault()

    const dataset = event.currentTarget.dataset

    // Populate food info in the sheet
    this.foodNameTarget.textContent = dataset.sheetNameParam
    this.foodCaloriesTarget.textContent = `${Math.round(parseFloat(dataset.sheetCaloriesParam))} kcal per 100g`

    // Store per-100g values for the preview controller
    this.panelTarget.dataset.caloriesPer100 = dataset.sheetCaloriesParam
    this.panelTarget.dataset.proteinPer100 = dataset.sheetProteinParam
    this.panelTarget.dataset.carbsPer100 = dataset.sheetCarbsParam
    this.panelTarget.dataset.fatPer100 = dataset.sheetFatParam
    this.panelTarget.dataset.fiberPer100 = dataset.sheetFiberParam

    // Set food_id or USDA fields
    if (dataset.sheetFoodIdParam) {
      this.foodIdFieldTarget.value = dataset.sheetFoodIdParam
      this.foodIdFieldTarget.disabled = false
      this.usdaFdcIdFieldTarget.disabled = true
    } else {
      this.foodIdFieldTarget.disabled = true
      this.usdaFdcIdFieldTarget.value = dataset.sheetUsdaFdcIdParam
      this.usdaFdcIdFieldTarget.disabled = false
      this.usdaNameFieldTarget.value = dataset.sheetNameParam
      this.usdaCaloriesFieldTarget.value = dataset.sheetCaloriesParam
      this.usdaProteinFieldTarget.value = dataset.sheetProteinParam
      this.usdaCarbsFieldTarget.value = dataset.sheetCarbsParam
      this.usdaFatFieldTarget.value = dataset.sheetFatParam
      this.usdaFiberFieldTarget.value = dataset.sheetFiberParam
    }

    this.overlayTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
  }

  close(event) {
    if (event) event.preventDefault()
    this.overlayTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  closeOnOverlay(event) {
    if (event.target === this.overlayTarget) {
      this.close(event)
    }
  }
}
