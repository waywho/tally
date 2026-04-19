import { Controller } from "@hotwired/stimulus"

// Debounced search that submits a form targeting a Turbo Frame.
// Usage:
//   <form data-controller="search" data-search-target="form" data-turbo-frame="food_search_results">
//     <input data-search-target="input" data-action="input->search#debounce">
//   </form>
export default class extends Controller {
  static targets = ["input", "form"]

  connect() {
    this.timeout = null
  }

  debounce() {
    clearTimeout(this.timeout)

    const query = this.inputTarget.value.trim()
    if (query.length < 3 && query.length > 0) return

    this.timeout = setTimeout(() => {
      this.formTarget.requestSubmit()
    }, 300)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
