import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Sends a "scan" message to the native barcode scanner bridge component.
// Modes:
//   "search" — navigates to the barcode lookup endpoint with the scanned code
//   "input"  — fills the scanned code into a target text field
export default class extends BridgeComponent {
  static component = "barcode-scanner"
  static values = {
    mode: { type: String, default: "search" },
    inputSelector: String,
    meal: String,
    date: String
  }

  scan() {
    this.send("scan", {}, (message) => {
      const barcode = message?.data?.barcode
      if (!barcode) return

      if (this.modeValue === "input") {
        const input = document.querySelector(this.inputSelectorValue)
        if (input) {
          input.value = barcode
          input.dispatchEvent(new Event("input", { bubbles: true }))
        }
      } else {
        const params = new URLSearchParams({ code: barcode })
        if (this.mealValue) params.set("meal", this.mealValue)
        if (this.dateValue) params.set("date", this.dateValue)
        window.location.href = `/foods/barcode_lookup?${params}`
      }
    })
  }
}
