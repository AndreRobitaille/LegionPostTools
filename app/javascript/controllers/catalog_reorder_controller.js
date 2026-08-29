import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Connected drag-and-drop lists for the Agenda Item Catalog. Every category is
// submitted after a drop so cross-category moves are validated and saved as one
// atomic arrangement. The server-rendered move buttons are the non-drag path.
export default class extends Controller {
  static targets = ["list", "status"]
  static values = { url: String }

  connect() {
    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.sortables = this.listTargets.map((list) => Sortable.create(list, {
      group: "agenda-item-catalog",
      handle: ".pos-handle",
      draggable: "[data-reorder-item]",
      animation: reduceMotion ? 0 : 150,
      emptyInsertThreshold: 24,
      ghostClass: "pos-ghost",
      dragClass: "pos-drag",
      onStart: () => this.startDrag(),
      onEnd: () => this.finishDrag(),
    }))
    this.refreshInterface()
  }

  disconnect() {
    this.sortables?.forEach((sortable) => sortable.destroy())
  }

  startDrag() {
    this.snapshot = this.listTargets.map((list) => ({ list, rows: this.rows(list) }))
    this.element.classList.add("catalog-reorder--dragging")
  }

  finishDrag() {
    this.element.classList.remove("catalog-reorder--dragging")
    this.refreshInterface()
    this.save()
  }

  rows(list) {
    return Array.from(list.children).filter((element) => element.matches("[data-reorder-item]"))
  }

  categories() {
    return Object.fromEntries(
      this.listTargets.map((list) => [
        list.dataset.category,
        this.rows(list).map((row) => row.dataset.reorderId),
      ]),
    )
  }

  async save() {
    this.setMoveButtonsDisabled(true)

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
        },
        body: JSON.stringify({ categories: this.categories() }),
      })
      if (!response.ok) throw new Error(`Catalog reorder failed: ${response.status}`)

      this.flash("Catalog order saved")
    } catch (error) {
      console.error(error)
      this.restore()
      this.flash("Could not save the catalog order — please try again", true)
    } finally {
      this.refreshInterface()
    }
  }

  restore() {
    this.snapshot?.forEach(({ list, rows }) => rows.forEach((row) => list.appendChild(row)))
  }

  refreshInterface() {
    this.listTargets.forEach((list) => {
      const count = this.rows(list).length
      const section = list.closest("[data-catalog-section]")
      const countLabel = section?.querySelector("[data-catalog-count]")
      const emptyState = list.querySelector("[data-catalog-empty]")

      if (countLabel) countLabel.textContent = `${count} ${count === 1 ? "item" : "items"}`
      emptyState?.classList.toggle("hidden", count > 0)
    })
    this.refreshMoveButtons()
  }

  refreshMoveButtons() {
    const rows = this.listTargets.flatMap((list) => this.rows(list))
    rows.forEach((row, index) => {
      const up = row.querySelector('[data-catalog-move-form="up"] button')
      const down = row.querySelector('[data-catalog-move-form="down"] button')
      if (up) up.disabled = index === 0
      if (down) down.disabled = index === rows.length - 1
    })
  }

  setMoveButtonsDisabled(disabled) {
    this.element.querySelectorAll(".catalog-move").forEach((button) => { button.disabled = disabled })
  }

  flash(message, isError = false) {
    this.statusTarget.textContent = message
    this.statusTarget.classList.toggle("pos-status-error", isError)
    clearTimeout(this.flashTimer)
    this.flashTimer = setTimeout(() => { this.statusTarget.textContent = "" }, 2500)
  }
}
