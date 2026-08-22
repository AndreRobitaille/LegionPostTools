import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "source", "status"]

  connect() {
    this.buttonTarget.hidden = false
    this.statusTarget.textContent = "Use Copy token, or select the token and copy it manually."
  }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.sourceTarget.value)
      this.statusTarget.textContent = "Token copied. Store it now; it will not be shown again."
      this.statusTarget.dataset.state = "success"
    } catch (_error) {
      this.sourceTarget.focus()
      this.sourceTarget.select()
      this.statusTarget.textContent = "Copy was not available. The token is selected so you can copy it manually."
      this.statusTarget.dataset.state = "error"
    }
  }
}
