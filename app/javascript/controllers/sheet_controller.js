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

    // Store per-100g values on the quantity-preview controller element
    const previewEl = this.panelTarget.querySelector('[data-controller="quantity-preview"]')
    if (previewEl) {
      previewEl.dataset.quantityPreviewCaloriesPer100Value = dataset.sheetCaloriesParam
      previewEl.dataset.quantityPreviewProteinPer100Value = dataset.sheetProteinParam
      previewEl.dataset.quantityPreviewCarbsPer100Value = dataset.sheetCarbsParam
      previewEl.dataset.quantityPreviewFatPer100Value = dataset.sheetFatParam
      previewEl.dataset.quantityPreviewFiberPer100Value = dataset.sheetFiberParam

      // Reset the grams input and preview when opening a new food
      const input = previewEl.querySelector('input[type="number"]')
      if (input) {
        input.value = ""
        input.dispatchEvent(new Event("input"))
      }
    }

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
