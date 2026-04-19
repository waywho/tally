import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["flash"]

  initialize() {
    this.flashTimeouts = []
  }

  disconnect() {
    this.clearFlashTimeout();
  }

  flashTargetConnected(element) {
    this.flashTimeouts.push(setTimeout(() => {
      element.remove()
    }, 3500))

  }

  clearFlashTimeout() {
    this.flashTimeouts.forEach((flashTimeout) => {
      clearTimeout(flashTimeout)
    })

    this.flashTimeouts = []
  }
}
