import { Controller } from "@hotwired/stimulus"

// A focused confirmation step for irreversible actions. Native <dialog> keeps
// focus inside the warning; this controller adds explicit focus restoration and
// lets a backdrop click behave like Cancel.
export default class extends Controller {
  static targets = ["dialog", "trigger", "cancel"]

  open() {
    this.dialogTarget.showModal()
    this.cancelTarget.focus()
  }

  close() {
    this.dialogTarget.close()
    this.triggerTarget.focus()
  }

  cancel(event) {
    event.preventDefault()
    this.close()
  }

  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
