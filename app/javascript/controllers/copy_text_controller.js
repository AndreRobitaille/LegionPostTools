import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "source", "status"]

  connect() {
    this.buttonTarget.hidden = false
    this.statusTarget.textContent = "Use Copy instructions, or select the text and copy it manually."
  }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.sourceTarget.value)
      this.statusTarget.textContent = "Instructions copied."
      this.statusTarget.dataset.state = "success"
    } catch (_error) {
      this.sourceTarget.focus()
      this.sourceTarget.select()
      this.statusTarget.textContent = "Copy was not available. The instructions are selected so you can copy them manually."
      this.statusTarget.dataset.state = "error"
    }
  }
}
