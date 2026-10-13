import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "row", "entry", "summary", "empty"]

  connect() {
    this.summarize()
  }

  filter() {
    const query = this.searchTarget.value.trim().toLocaleLowerCase()
    this.rowTargets.forEach(row => { row.hidden = !row.dataset.memberName.includes(query) })
    this.emptyTarget.hidden = this.rowTargets.some(row => !row.hidden)
  }

  summarize() {
    const counts = { present: 0, absent: 0, excused: 0, not_recorded: 0 }
    this.entryTargets.forEach(entry => { counts[entry.value] += 1 })
    this.summaryTarget.textContent = `${counts.present} present · ${counts.absent} absent · ${counts.excused} excused · ${counts.not_recorded} not recorded in the whole register`
  }
}
