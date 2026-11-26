import { Controller } from "@hotwired/stimulus"
import { create, get, supported } from "@github/webauthn-json"

// Drives the browser WebAuthn ceremonies against the app's JSON endpoints.
// Register: options -> navigator.credentials.create -> POST /passkeys/registration
// Authenticate: options -> navigator.credentials.get -> POST /passkeys/authentication
export default class extends Controller {
  static targets = ["status", "submit", "email", "controls", "unsupported", "retryCancel"]
  static values = {
    source: String,
    redirect: { type: String, default: "/" },
    optionsUrl: { type: String, default: "/passkeys/authentication_options" },
    verifyUrl: { type: String, default: "/passkeys/authentication" }
  }

  connect() {
    const available = supported()
    if (this.hasUnsupportedTarget) {
      this.unsupportedTarget.hidden = available
      this.controlsTargets.forEach(section => { section.hidden = !available })
      if (available && window.location.hash === "#add-passkey") {
        requestAnimationFrame(() => {
          this.element.querySelector("[autofocus]")?.focus({ preventScroll: true })
          this.element.scrollIntoView({ block: "nearest" })
        })
      }
    }
    if (this.hasSubmitTarget && this.hasEmailTarget && available) {
      this.submitTarget.hidden = false
      this.emailTarget.classList.replace("btn-primary", "btn-secondary")
    }
    if (!available) {
      // No WebAuthn in this browser: disable the trigger, leave the email link as the path.
      if (this.hasSubmitTarget) {
        this.submitTarget.disabled = true
        this.submitTarget.title = "This browser does not support passkeys"
      }
    }
  }

  async register(event) {
    event.preventDefault()
    if (!supported()) return
    this.#busy("Waiting for your device…")
    const details = this.#enrollmentDetails()
    try {
      const options = await this.#postJSON("/passkeys/registration_options", details)
      const credential = await create({ publicKey: options })
      await this.#postJSON("/passkeys/registration", { publicKeyCredential: credential, ...details })
      this.#visit(this.redirectValue)
    } catch (error) {
      if (error.confirmationUrl) {
        this.#visit(error.confirmationUrl)
        return
      }
      this.submitTarget.textContent = "Try again"
      if (this.hasRetryCancelTarget) this.retryCancelTarget.hidden = false
      this.#fail(["NotAllowedError", "AbortError"].includes(error.name)
        ? "Passkey setup was cancelled."
        : "Couldn’t add this passkey. Try again or sign in by email.")
      this.submitTarget.focus()
    }
  }

  async authenticate(event) {
    event.preventDefault()
    if (!supported()) return
    this.#busy("Waiting for your device…")
    try {
      const options = await this.#postJSON(this.optionsUrlValue, this.#enrollmentDetails())
      const assertion = await get({ publicKey: options })
      const res = await this.#postJSON(this.verifyUrlValue, { publicKeyCredential: assertion })
      if (res) this.#visit(res.redirect_url || this.redirectValue)
    } catch (error) {
      this.#fail(this.hasEmailTarget ? "Try your passkey again or use email." : "That didn't work — try the email link instead.")
    }
  }

  #visit(url) {
    // A fragment change alone would leave the old setup step on screen.
    const target = new URL(url, window.location.href)
    if (target.pathname === window.location.pathname && target.search === window.location.search) {
      window.history.replaceState(window.history.state, "", target)
      if (!target.hash) window.scrollTo(0, 0)
      window.location.reload()
    } else {
      window.location.assign(target)
    }
  }

  #enrollmentDetails() {
    if (!this.hasSourceValue) return

    const field = this.element.querySelector("[data-passkey-nickname]")
    return { nickname: field?.value.trim(), source: this.sourceValue }
  }

  async #postJSON(url, body) {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: body ? JSON.stringify(body) : "{}"
    })
    if (!response.ok) {
      const error = new Error(`Request to ${url} failed: ${response.status}`)
      if (response.status === 403) {
        const payload = await response.json()
        error.confirmationUrl = payload.confirmation_url
      }
      throw error
    }
    return response.json()
  }

  #busy(message) {
    if (this.hasSubmitTarget) this.submitTarget.disabled = true
    if (this.hasEmailTarget) this.emailTarget.disabled = true
    this.#status(message, false)
  }

  #fail(message) {
    if (this.hasSubmitTarget) this.submitTarget.disabled = false
    if (this.hasEmailTarget) this.emailTarget.disabled = false
    this.#status(message, true)
  }

  #status(message, isError) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message
    this.statusTarget.dataset.state = isError ? "error" : "busy"
  }
}
