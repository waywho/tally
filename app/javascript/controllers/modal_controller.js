import { Controller } from "@hotwired/stimulus"

// Single layout-mounted modal. Triggers open with:
//   data-turbo-frame="modal"            (Turbo fetches body into the frame)
//   data-action="click->modal#open"     (we show the chrome)
// Close: backdrop click, close button, ESC key.
export default class extends Controller {
  static targets = ["root", "frame"]

  open() {
    this.rootTarget.classList.remove("hidden")
    this.rootTarget.classList.add("flex")
    document.body.classList.add("overflow-hidden")
  }

  close(event) {
    if (event) event.preventDefault()
    this.rootTarget.classList.add("hidden")
    this.rootTarget.classList.remove("flex")
    document.body.classList.remove("overflow-hidden")
    // Reset frame so the next open re-fetches.
    this.frameTarget.innerHTML = ""
  }
}
