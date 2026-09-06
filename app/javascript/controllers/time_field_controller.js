import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  normalize() {
    const text = this.element.value.trim()
    const match = text.match(/^(\d{1,2})(?::([0-5]\d))?\s*(am|pm)?$/i) ||
      text.match(/^(\d{1,2})([0-5]\d)\s*(am|pm)?$/i)
    if (!match) return
    let hour = Number(match[1])
    const period = match[3]?.toLowerCase()
    if (period ? hour < 1 || hour > 12 : hour > 23) return
    if (period) hour = hour % 12 + (period === "pm" ? 12 : 0)
    this.element.value = `${String(hour).padStart(2, "0")}:${match[2] || "00"}`
  }
}
