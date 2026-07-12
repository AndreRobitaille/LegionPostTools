import { Controller } from "@hotwired/stimulus"

const MONTHS = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]

export default class extends Controller {
  static targets = ["text", "native"]

  open() {
    if (typeof this.nativeTarget.showPicker === "function") {
      this.nativeTarget.showPicker()
    } else {
      this.nativeTarget.focus()
    }
  }

  pick() {
    const value = this.nativeTarget.value // yyyy-mm-dd
    if (!value) return
    const [year, month, day] = value.split("-")
    this.textTarget.value = `${day} ${MONTHS[parseInt(month, 10) - 1]} ${year}`
  }
}
