import { Controller } from "@hotwired/stimulus"

// Manages dynamic addition and removal of recipe ingredient rows.
// Uses a <template> element containing a blank ingredient row.
// New rows get a unique timestamp-based index for Rails nested attributes.
//
// Usage:
//   <form data-controller="recipe-ingredients">
//     <div data-recipe-ingredients-target="container">
//       <!-- existing ingredient rows -->
//     </div>
//     <template data-recipe-ingredients-target="template">
//       <!-- blank ingredient row with NEW_INDEX placeholder -->
//     </template>
//     <button data-action="click->recipe-ingredients#add">Add</button>
//   </form>
export default class extends Controller {
  static targets = ["container", "template", "row", "destroyField"]

  add() {
    const content = this.templateTarget.innerHTML.replace(/NEW_INDEX/g, new Date().getTime())
    this.containerTarget.insertAdjacentHTML("beforeend", content)
  }

  remove(event) {
    const row = event.target.closest("[data-recipe-ingredients-target='row']")

    // If the row has a destroy field (persisted record), mark for destruction
    const destroyField = row.querySelector("[data-recipe-ingredients-target='destroyField']")
    if (destroyField) {
      destroyField.value = "1"
      row.style.display = "none"
    } else {
      // New unsaved row — just remove from DOM
      row.remove()
    }
  }
}
