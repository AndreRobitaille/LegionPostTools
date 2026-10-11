import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["assignment", "purpose", "outcome"]

  connect() {
    this.update()
  }

  update() {
    const assignmentPurpose = this.hasAssignmentTarget
      ? this.assignmentTarget.selectedOptions[0]?.dataset.purpose
      : null
    if (this.hasPurposeTarget) {
      this.purposeTarget.disabled = Boolean(assignmentPurpose)
      if (assignmentPurpose) this.purposeTarget.value = assignmentPurpose
    }
    const purpose = assignmentPurpose || (this.hasPurposeTarget ? this.purposeTarget.value : "renewal")
    const renewalOutcomes = ["already_paid_online", "wants_to_renew", "declined_renewal"]
    for (const option of this.outcomeTarget.options) {
      const excluded = purpose === "buddy_check" && renewalOutcomes.includes(option.value)
      option.hidden = excluded
      option.disabled = excluded
      if (excluded && option.selected) this.outcomeTarget.value = ""
    }
  }
}
