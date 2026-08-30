import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "body", "name", "address" ]
  static values = { locations: Object }

  bodyChanged() {
    const location = this.locationsValue[this.bodyTarget.value]
    if (!location) return

    this.nameTarget.value = location.name || ""
    this.addressTarget.value = location.address || ""
  }
}
