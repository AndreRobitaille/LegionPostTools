import { Controller } from "@hotwired/stimulus"

// Click-to-edit for a single text field. Shows read-only display markup with an
// Edit button; on edit, hides the display and reveals a form (a normal Turbo
// form) with the field focused. Cancel restores the display without submitting.
// Saving is the form's own Turbo submit, which reloads the page in saved state.
export default class extends Controller {
  static targets = ["display", "form", "field"]

  connect() {
    this.showDisplay()
  }

  edit() {
    this.displayTarget.hidden = true
    this.formTarget.hidden = false
    this.fieldTarget.focus()
    this.fieldTarget.select()
  }

  cancel() {
    this.fieldTarget.value = this.fieldTarget.defaultValue
    this.showDisplay()
  }

  showDisplay() {
    this.displayTarget.hidden = false
    this.formTarget.hidden = true
  }
}
