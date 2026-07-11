import { Controller } from "@hotwired/stimulus"

// Edit-in-place for a passkey name. Progressive enhancement: without JS the field
// is a plain editable input with a "Save" submit button. With JS, the field starts
// read-only (looks like text) behind an "Edit" button; clicking Edit makes it
// editable and flips the button to "Save", which submits the rename form.
export default class extends Controller {
  static targets = ["field", "button"]

  connect() {
    this.editing = false
    this.fieldTarget.readOnly = true
    this.buttonTarget.textContent = "Edit"
  }

  toggle(event) {
    if (this.editing) return // let the submit proceed

    event.preventDefault()
    this.editing = true
    this.fieldTarget.readOnly = false
    this.fieldTarget.focus()
    this.fieldTarget.setSelectionRange(this.fieldTarget.value.length, this.fieldTarget.value.length)
    this.buttonTarget.textContent = "Save"
  }
}
