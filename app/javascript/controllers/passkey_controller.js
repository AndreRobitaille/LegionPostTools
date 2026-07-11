import { Controller } from "@hotwired/stimulus"
import { create, get, supported } from "@github/webauthn-json"

// Drives the browser WebAuthn ceremonies against the app's JSON endpoints.
// Register: options -> navigator.credentials.create -> POST /passkeys/registration
// Authenticate: options -> navigator.credentials.get -> POST /passkeys/authentication
export default class extends Controller {
  static targets = ["status", "submit"]
  static values = { redirect: { type: String, default: "/" } }

  connect() {
    if (!supported()) {
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
    try {
      const options = await this.#postJSON("/passkeys/registration_options")
      const credential = await create({ publicKey: options })
      const nickname = this.#nickname()
      const res = await this.#postJSON("/passkeys/registration", { publicKeyCredential: credential, nickname })
      if (res) window.location.assign(this.redirectValue)
    } catch (error) {
      this.#fail("We couldn't add that passkey. You can try again, or keep using the email link.")
    }
  }

  async authenticate(event) {
    event.preventDefault()
    if (!supported()) return
    this.#busy("Waiting for your device…")
    try {
      const options = await this.#postJSON("/passkeys/authentication_options")
      const assertion = await get({ publicKey: options })
      const res = await this.#postJSON("/passkeys/authentication", { publicKeyCredential: assertion })
      if (res) window.location.assign(this.redirectValue)
    } catch (error) {
      this.#fail("That didn't work — try the email link instead.")
    }
  }

  #nickname() {
    const field = this.element.querySelector("[data-passkey-nickname]")
    return field && field.value.trim() ? field.value.trim() : null
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
    if (!response.ok) throw new Error(`Request to ${url} failed: ${response.status}`)
    return response.json()
  }

  #busy(message) {
    if (this.hasSubmitTarget) this.submitTarget.disabled = true
    this.#status(message, false)
  }

  #fail(message) {
    if (this.hasSubmitTarget) this.submitTarget.disabled = false
    this.#status(message, true)
  }

  #status(message, isError) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message
    this.statusTarget.dataset.state = isError ? "error" : "busy"
  }
}
