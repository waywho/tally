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

  clear(event) {
    if (event) event.preventDefault()
    clearTimeout(this.timeout)
    this.inputTarget.value = ""
    this.inputTarget.focus()
    // Drop the q param from the URL and navigate so suggestions (meal templates,
    // quick-add) come back — they live outside the turbo frame, so a frame
    // submission alone wouldn't reveal them.
    const url = new URL(window.location.href)
    url.searchParams.delete("q")
    window.Turbo ? window.Turbo.visit(url.toString()) : (window.location.href = url.toString())
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
