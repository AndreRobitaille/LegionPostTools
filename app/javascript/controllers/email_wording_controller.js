import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["subject", "coverNote", "destination", "kind", "subjectPreview", "notePreview", "correctionPreview"]
  static values = { values: Object, subject: String, coverNote: String, correctionNotice: String }

  connect() {
    if (this.hasSubjectTarget) this.activeField = this.subjectTarget
    this.render()
  }

  selectField(event) {
    this.activeField = event.currentTarget
    this.destinationTarget.textContent = `Insert a variable into: ${this.activeField === this.subjectTarget ? "Subject" : "Cover note"}`
  }

  insert(event) {
    const field = this.activeField || this.subjectTarget
    field.setRangeText(event.params.token, field.selectionStart, field.selectionEnd, "end")
    field.focus()
    this.render()
  }

  render() {
    const corrected = this.kindTarget.value === "corrected"
    const values = { ...this.valuesValue, copy_label: corrected ? "Corrected minutes" : "Minutes" }
    const fill = text => text.replace(/\{\{\s*([a-z_]+)\s*\}\}/g, (token, name) => values[name] ?? token)
    this.subjectPreviewTarget.textContent = fill(this.hasSubjectTarget ? this.subjectTarget.value : this.subjectValue)
    this.notePreviewTarget.textContent = fill(this.hasCoverNoteTarget ? this.coverNoteTarget.value : this.coverNoteValue)
    this.correctionPreviewTarget.hidden = !corrected
    this.correctionPreviewTarget.textContent = this.correctionNoticeValue
  }
}
