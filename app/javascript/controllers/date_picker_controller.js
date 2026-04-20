import { Controller } from "@hotwired/stimulus"

// Opens a native date picker and navigates to the selected date.
// Usage:
//   <div data-controller="date-picker">
//     <span data-action="click->date-picker#open">Today</span>
//     <input type="date" class="sr-only" data-date-picker-target="input" data-action="change->date-picker#navigate">
//   </div>
export default class extends Controller {
  static targets = ["input"]

  open() {
    this.inputTarget.showPicker()
  }

  navigate() {
    const date = this.inputTarget.value
    if (date) {
      window.location.href = `/days/${date}`
    }
  }
}
