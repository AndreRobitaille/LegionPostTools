import { Controller } from "@hotwired/stimulus"

// The header's "Menu" button. Opens on click only — never hover, which is hard
// to use with a tremor and meaningless on touch. Escape closes it and puts focus
// back on the button; clicking anywhere else closes it too. Arrow keys walk the
// menu items so it is usable without a mouse.
export default class extends Controller {
  static targets = ["button", "panel"]

  connect() {
    this.closeOnOutsideClick = this.closeOnOutsideClick.bind(this)
    this.fitPanelToViewport = this.fitPanelToViewport.bind(this)
    this.close()
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnOutsideClick)
    window.removeEventListener("resize", this.fitPanelToViewport)
  }

  toggle(event) {
    event.stopPropagation()
    this.isOpen ? this.close() : this.open()
  }

  open() {
    this.isOpen = true
    this.panelTarget.hidden = false
    this.buttonTarget.setAttribute("aria-expanded", "true")
    this.fitPanelToViewport()
    document.addEventListener("click", this.closeOnOutsideClick)
    window.addEventListener("resize", this.fitPanelToViewport)
  }

  close() {
    this.isOpen = false
    this.panelTarget.hidden = true
    this.buttonTarget.setAttribute("aria-expanded", "false")
    document.removeEventListener("click", this.closeOnOutsideClick)
    window.removeEventListener("resize", this.fitPanelToViewport)
  }

  fitPanelToViewport() {
    if (!this.isOpen) return

    const top = this.panelTarget.getBoundingClientRect().top
    this.panelTarget.style.maxHeight = `${Math.max(0, window.innerHeight - top - 12)}px`
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
      .filter(item => item.getClientRects().length > 0)
    if (items.length === 0) return

    event.preventDefault()
    const current = items.indexOf(document.activeElement)
    let next = current + step
    if (current === -1) next = step > 0 ? 0 : items.length - 1
    items[(next + items.length) % items.length].focus()
  }
}
