import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["choice", "other", "otherSelect"]

  connect() {
    this.updateOther()
  }

  change() {
    this.updateOther()
  }

  updateOther() {
    const selected = this.choiceTargets.find((choice) => choice.checked)
    const showOther = selected?.value === "other"

    this.otherTarget.hidden = !showOther
    this.otherSelectTarget.disabled = !showOther
    this.otherSelectTarget.required = showOther
  }
}
