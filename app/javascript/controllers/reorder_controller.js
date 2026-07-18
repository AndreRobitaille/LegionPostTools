import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Drag-to-reorder for the Post Positions list. Progressive enhancement: without
// JS the rows render in saved order (just not draggable). With JS, each row is
// draggable by its .pos-handle grip; dropping a row POSTs the new id order and
// persists immediately. On failure the pre-drag order is restored.
export default class extends Controller {
  static targets = ["list", "status"]
  static values = { url: String }

  connect() {
    this.sortable = Sortable.create(this.listTarget, {
      handle: ".pos-handle",
      animation: 150,
      ghostClass: "pos-ghost",
      dragClass: "pos-drag",
      onStart: () => { this.snapshot = this.rows() },
      onEnd: () => this.save(),
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  rows() {
    return Array.from(this.listTarget.querySelectorAll("[data-position-id]"))
  }

  async save() {
    const ids = this.rows().map((el) => el.dataset.positionId)
    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
        },
        body: JSON.stringify({ ids }),
      })
      if (!response.ok) throw new Error(`Reorder failed: ${response.status}`)
      this.flash("Order saved")
    } catch (error) {
      console.error(error)
      this.restore()
      this.flash("Could not save order — please try again", true)
    }
  }

  // Re-append rows in their pre-drag sequence to undo the visual move.
  restore() {
    this.snapshot?.forEach((el) => this.listTarget.appendChild(el))
  }

  flash(message, isError = false) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message
    this.statusTarget.classList.toggle("pos-status-error", isError)
    clearTimeout(this.flashTimer)
    this.flashTimer = setTimeout(() => { this.statusTarget.textContent = "" }, 2500)
  }
}
