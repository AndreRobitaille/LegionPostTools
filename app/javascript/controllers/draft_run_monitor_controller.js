import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["badge", "heading", "message", "stageTitle", "checkButton"]
  static values = {
    statusUrl: String,
    destinationUrl: String,
    interval: { type: Number, default: 5000 }
  }

  connect() {
    this.schedule()
  }

  disconnect() {
    this.cancelScheduledCheck()
  }

  checkNow() {
    this.cancelScheduledCheck()
    this.check()
  }

  schedule() {
    this.timeout = window.setTimeout(() => this.check(), this.intervalValue)
  }

  cancelScheduledCheck() {
    if (this.timeout) window.clearTimeout(this.timeout)
    this.timeout = null
  }

  async check() {
    this.setChecking(true)

    try {
      const response = await fetch(this.statusUrlValue, {
        cache: "no-store",
        credentials: "same-origin",
        headers: { Accept: "application/json" }
      })
      if (!response.ok) throw new Error(`Status request failed: ${response.status}`)

      const { status } = await response.json()
      if (["succeeded", "failed"].includes(status)) {
        Turbo.visit(this.destinationUrlValue, { action: "replace" })
        return
      }

      this.render(status)
    } catch (_error) {
      this.messageTarget.textContent = "The status check was interrupted. We will try again automatically; the draft continues in the background."
    }

    this.setChecking(false)
    this.schedule()
  }

  render(status) {
    this.element.dataset.state = status

    if (status === "running") {
      this.badgeTarget.textContent = "Drafting"
      this.headingTarget.textContent = "OpenAI is preparing suggestions"
      this.stageTitleTarget.textContent = "Preparing suggestions"
      this.messageTarget.textContent = "OpenAI is organizing source-linked suggestions. This can take up to several minutes."
    } else {
      this.badgeTarget.textContent = "Queued"
      this.headingTarget.textContent = "Your draft is in line"
      this.stageTitleTarget.textContent = "Waiting for worker"
      this.messageTarget.textContent = "The request is recorded and waiting for the background drafting worker."
    }
  }

  setChecking(checking) {
    this.checkButtonTarget.disabled = checking
    this.checkButtonTarget.textContent = checking ? "Checking…" : "Check status now"
  }
}
