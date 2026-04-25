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

      // Pre-fill the grams input with the last weight the user used for this
      // food (passed via sheet-weight-param from quick-add rows) — otherwise
      // default to 100g so the submit button is enabled and the preview shows
      // the per-100g values verbatim. Focus + select so the user can type a
      // different number immediately.
      const input = previewEl.querySelector('input[type="number"]')
      if (input) {
        input.value = dataset.sheetWeightParam || "100"
        input.dispatchEvent(new Event("input"))
        // Focus after the panel is shown so the keyboard pops on mobile.
        requestAnimationFrame(() => {
          input.focus()
          input.select()
        })
      }
    }

    // Set food_id or USDA fields
    if (dataset.sheetFoodIdParam) {
      this.foodIdFieldTarget.value = dataset.sheetFoodIdParam
      this.foodIdFieldTarget.disabled = false
      this.usdaFdcIdFieldTarget.disabled = true
    } else {
      // USDA transient result: server needs every nutrient param to persist
      // the food. The hidden inputs ship `disabled` so they don't pollute the
      // saved-food path — flip them on here.
      this.foodIdFieldTarget.disabled = true
      this.usdaFdcIdFieldTarget.value = dataset.sheetUsdaFdcIdParam
      this.usdaFdcIdFieldTarget.disabled = false
      this.usdaNameFieldTarget.value = dataset.sheetNameParam
      this.usdaNameFieldTarget.disabled = false
      this.usdaCaloriesFieldTarget.value = dataset.sheetCaloriesParam
      this.usdaCaloriesFieldTarget.disabled = false
      this.usdaProteinFieldTarget.value = dataset.sheetProteinParam
      this.usdaProteinFieldTarget.disabled = false
      this.usdaCarbsFieldTarget.value = dataset.sheetCarbsParam
      this.usdaCarbsFieldTarget.disabled = false
      this.usdaFatFieldTarget.value = dataset.sheetFatParam
      this.usdaFatFieldTarget.disabled = false
      this.usdaFiberFieldTarget.value = dataset.sheetFiberParam
      this.usdaFiberFieldTarget.disabled = false
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
