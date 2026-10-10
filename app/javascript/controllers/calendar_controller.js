import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["category", "entry", "day", "empty", "count", "navigation", "enhancement", "monthButton", "scheduleButton", "displayField"]
  static values = { display: String }

  connect() {
    this.enhancementTargets.forEach(element => element.hidden = false)
    this.applyFilters()
    this.updateDisplay()
  }

  filter() {
    this.applyFilters()
    this.updateLocation()
  }

  selectAll() {
    this.categoryTargets.forEach(input => input.checked = true)
    this.filter()
  }

  selectNone() {
    this.categoryTargets.forEach(input => input.checked = false)
    this.filter()
  }

  showMonth() { this.setDisplay("month") }
  showSchedule() { this.setDisplay("schedule") }

  setDisplay(display) {
    this.displayValue = display
    this.updateDisplay()
    this.updateLocation()
  }

  updateDisplay() {
    this.monthButtonTarget.setAttribute("aria-pressed", this.displayValue === "month")
    this.scheduleButtonTarget.setAttribute("aria-pressed", this.displayValue === "schedule")
    this.displayFieldTarget.value = this.displayValue
  }

  applyFilters() {
    const selected = new Set(this.categoryTargets.filter(input => input.checked).map(input => input.value))
    this.entryTargets.forEach(entry => entry.hidden = !selected.has(entry.dataset.category))
    let count = 0
    this.dayTargets.forEach(day => {
      const entries = [...day.querySelectorAll(".calendar-row")].filter(entry => !entry.hidden)
      day.hidden = entries.length === 0
      count += entries.length
    })
    this.emptyTarget.hidden = count > 0
    this.countTarget.textContent = `${count} ${count === 1 ? "event" : "events"} this month`
  }

  updateLocation() {
    const selected = this.categoryTargets.filter(input => input.checked).map(input => input.value)
    const update = url => {
      url.searchParams.delete("categories[]")
      url.searchParams.delete("categories")
      const values = selected.length ? selected : [""]
      values.forEach(value => url.searchParams.append("categories[]", value))
      url.searchParams.set("display", this.displayValue)
      return url
    }
    window.history.replaceState(window.history.state, "", update(new URL(window.location.href)))
    this.navigationTargets.forEach(link => link.href = update(new URL(link.href)))
  }
}
