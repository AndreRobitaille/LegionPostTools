import { Controller } from "@hotwired/stimulus"
import { get, supported } from "@github/webauthn-json"

export default class extends Controller {
  static targets = ["passkey", "email", "status", "decision"]

  connect() {
    this.describeDecision()
    if (this.hasPasskeyTarget && supported()) {
      this.passkeyTarget.hidden = false
      this.emailTarget.classList.replace("btn-primary", "btn-secondary")
    }
  }

  describeDecision() {
    if (!this.hasDecisionTarget) return

    const fields = this.element.elements
    const disposition = fields["minutes_membership_approval[disposition]"].value
    if (!disposition) return

    const pending = disposition === "approved_as_corrected" && !this.element.querySelector("input[type=checkbox]").checked
    this.decisionTarget.textContent = pending
      ? "The decision is recorded. The Adjutant locks the corrected copy after the corrections are entered."
      : "Recording approval locks this exact copy."
  }

  async sign() {
    const form = this.element
    if (!form.reportValidity()) return

    const body = new FormData(form)
    body.set("identity_method", "passkey")
    this.passkeyTarget.disabled = true
    this.emailTarget.disabled = true
    this.statusTarget.textContent = "Waiting for your device…"
    try {
      const headers = { Accept: "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content }
      const start = await fetch(form.action, { method: "POST", body, headers })
      if (start.redirected) {
        window.location.assign(start.url)
        return
      }
      if (!start.ok) {
        const details = await start.json().catch(() => ({}))
        this.statusTarget.textContent = details.error || "Review the minutes and try again."
        return
      }
      const { options, confirmation_id, verify_url } = await start.json()
      const assertion = await get({ publicKey: options })
      const result = await fetch(verify_url, {
        method: "POST",
        headers: { ...headers, "Content-Type": "application/json" },
        body: JSON.stringify({ confirmation_id, publicKeyCredential: assertion })
      })
      if (result.redirected) {
        window.location.assign(result.url)
        return
      }
      if (!result.ok) throw new Error()
      window.location.assign((await result.json()).redirect_url)
    } catch (error) {
      this.statusTarget.textContent = error.name === "NotAllowedError"
        ? "Passkey cancelled. Try again or use email."
        : "We couldn’t confirm with that passkey. Try again or use email."
    } finally {
      this.passkeyTarget.disabled = false
      this.emailTarget.disabled = false
    }
  }
}
