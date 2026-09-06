import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "content", "close"]

  async open(event) {
    if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    if (new URL(event.currentTarget.href).origin !== window.location.origin) return
    event.preventDefault()
    this.request?.abort()
    this.trigger = event.currentTarget
    const request = new AbortController()
    this.request = request
    this.contentTarget.textContent = "Loading source…"
    this.dialogTarget.showModal()
    document.documentElement.classList.add("source-reader-open")
    this.closeTarget.focus()

    try {
      const response = await fetch(this.trigger.href, { signal: request.signal, credentials: "same-origin" })
      if (!response.ok || response.redirected) throw new Error("Source unavailable")
      const page = new DOMParser().parseFromString(await response.text(), "text/html")
      const source = page.querySelector(".endeavor-source-document")
      if (!source) throw new Error("Source unavailable")
      if (this.request === request && !request.signal.aborted) this.contentTarget.replaceChildren(source)
    } catch (error) {
      if (error.name !== "AbortError" && this.request === request && !request.signal.aborted) {
        this.contentTarget.textContent = "This source is no longer available. Close this panel and refresh the Endeavor."
      }
    }
  }

  openBackground() {
    this.element.querySelector("#endeavor-background").open = true
  }

  close() {
    this.dialogTarget.close()
  }

  closed() {
    this.request?.abort()
    document.documentElement.classList.remove("source-reader-open")
    this.trigger?.focus({ preventScroll: true })
  }

  backdrop(event) {
    if (event.target !== this.dialogTarget) return
    const bounds = this.dialogTarget.getBoundingClientRect()
    if (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom) this.close()
  }

  disconnect() {
    this.request?.abort()
    document.documentElement.classList.remove("source-reader-open")
  }

  beforeCache() {
    if (this.dialogTarget.open) this.close()
    this.contentTarget.replaceChildren()
  }
}
