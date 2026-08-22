import { Controller } from "@hotwired/stimulus"

// The header's "Menu" button. Opens on click only — never hover, which is hard
// to use with a tremor and meaningless on touch. Escape closes it and puts focus
// back on the button; clicking anywhere else closes it too. Arrow keys walk the
// menu items so it is usable without a mouse.
export default class extends Controller {
  static targets = ["button", "panel"]

  connect() {
    this.closeOnOutsideClick = this.closeOnOutsideClick.bind(this)
    this.close()
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnOutsideClick)
  }

  toggle(event) {
    event.stopPropagation()
    this.isOpen ? this.close() : this.open()
  }

  open() {
    this.isOpen = true
    this.panelTarget.hidden = false
    this.buttonTarget.setAttribute("aria-expanded", "true")
    document.addEventListener("click", this.closeOnOutsideClick)
  }

  close() {
    this.isOpen = false
    this.panelTarget.hidden = true
    this.buttonTarget.setAttribute("aria-expanded", "false")
    document.removeEventListener("click", this.closeOnOutsideClick)
  }

  // Escape anywhere in the menu returns you to the button you opened it with,
  // so keyboard users are never stranded.
  closeAndRefocus() {
    if (!this.isOpen) return

    this.close()
    this.buttonTarget.focus()
  }

  closeOnOutsideClick(event) {
    if (this.element.contains(event.target)) return

    this.close()
  }

  moveNext(event) {
    this.moveFocus(event, 1)
  }

  movePrevious(event) {
    this.moveFocus(event, -1)
  }

  moveFocus(event, step) {
    if (!this.isOpen) return

    const items = Array.from(this.panelTarget.querySelectorAll("a, button"))
    if (items.length === 0) return

    event.preventDefault()
    const current = items.indexOf(document.activeElement)
    const next = (current + step + items.length) % items.length
    items[next].focus()
  }
}
