import { Controller } from "@hotwired/stimulus"

// Horizontal scroll snap for tally card pages with dot indicators.
// Usage:
//   <div data-controller="swipe">
//     <div data-swipe-target="container" class="flex overflow-x-auto snap-x snap-mandatory">
//       <div class="snap-center min-w-full">Page 1</div>
//       <div class="snap-center min-w-full">Page 2</div>
//     </div>
//     <div class="flex justify-center gap-1.5 mt-2">
//       <span data-swipe-target="dot" class="w-1.5 h-1.5 rounded-full bg-primary"></span>
//       <span data-swipe-target="dot" class="w-1.5 h-1.5 rounded-full bg-border"></span>
//     </div>
//   </div>
export default class extends Controller {
  static targets = ["container", "dot"]

  connect() {
    this.handleScroll = this.updateDots.bind(this)
    this.containerTarget.addEventListener("scroll", this.handleScroll)
  }

  disconnect() {
    this.containerTarget.removeEventListener("scroll", this.handleScroll)
  }

  updateDots() {
    const container = this.containerTarget
    const scrollLeft = container.scrollLeft
    const pageWidth = container.offsetWidth
    const currentPage = Math.round(scrollLeft / pageWidth)

    this.dotTargets.forEach((dot, index) => {
      if (index === currentPage) {
        dot.classList.remove("bg-border")
        dot.classList.add("bg-primary")
      } else {
        dot.classList.remove("bg-primary")
        dot.classList.add("bg-border")
      }
    })
  }
}
