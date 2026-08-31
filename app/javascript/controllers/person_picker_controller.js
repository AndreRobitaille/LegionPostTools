import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["id", "input", "results", "clear", "unidentified"]
  static values = { sourceId: String, selectedId: String }

  connect() {
    this.activeIndex = -1
    this.matches = []
    this.people = this.loadPeople()
    this.syncSelectedPerson()
    this.updateValidity()
    this.updateClearButton()
  }

  search() {
    if (this.unidentifiedTarget.checked) return

    if (this.selectedPerson()?.name !== this.inputTarget.value) this.idTarget.value = ""
    const query = this.normalize(this.inputTarget.value)
    this.matches = query.length < 1 ? [] : this.rankedMatches(query).slice(0, 8)
    this.activeIndex = -1
    this.renderResults()
    this.updateValidity()
    this.updateClearButton()
  }

  navigate(event) {
    if (event.key === "Escape") return this.closeResults()
    if (!["ArrowDown", "ArrowUp", "Enter"].includes(event.key)) return
    if (this.matches.length === 0) return

    event.preventDefault()
    if (event.key === "Enter" && this.activeIndex >= 0) return this.select(this.matches[this.activeIndex])

    const direction = event.key === "ArrowDown" ? 1 : -1
    this.activeIndex = (this.activeIndex + direction + this.matches.length) % this.matches.length
    this.renderResults()
  }

  choose(event) {
    const person = this.people.find((candidate) => candidate.id.toString() === event.currentTarget.dataset.personId)
    if (person) this.select(person)
  }

  clear() {
    this.idTarget.value = ""
    this.inputTarget.value = ""
    this.unidentifiedTarget.checked = false
    this.inputTarget.disabled = false
    this.closeResults()
    this.updateValidity()
    this.updateClearButton()
    this.inputTarget.focus()
  }

  toggleUnidentified() {
    const unidentified = this.unidentifiedTarget.checked
    this.idTarget.value = ""
    this.inputTarget.value = ""
    this.inputTarget.disabled = unidentified
    this.closeResults()
    this.updateValidity()
    this.updateClearButton()
    if (!unidentified) this.inputTarget.focus()
  }

  select(person) {
    this.idTarget.value = person.id
    this.inputTarget.value = person.name
    this.unidentifiedTarget.checked = false
    this.closeResults()
    this.updateValidity()
    this.updateClearButton()
  }

  selectedPerson() {
    return this.people.find((person) => person.id.toString() === this.idTarget.value)
  }

  syncSelectedPerson() {
    const selected = this.people.find((person) => person.id.toString() === this.selectedIdValue)
    if (selected && !this.unidentifiedTarget.checked) {
      this.idTarget.value = selected.id
      this.inputTarget.value = selected.name
    }
  }

  rankedMatches(query) {
    return this.people
      .map((person) => ({ person, score: this.score(query, this.normalize(person.search)) }))
      .filter(({ score }) => Number.isFinite(score))
      .sort((left, right) => left.score - right.score || left.person.name.localeCompare(right.person.name))
      .map(({ person }) => person)
  }

  score(query, candidate) {
    if (candidate === query) return 0
    if (candidate.startsWith(query)) return 1
    if (candidate.split(/\s+/).some((word) => word.startsWith(query))) return 2
    if (candidate.includes(query)) return 3
    if (query.length >= 3 && candidate.split(/\s+/).some((word) => this.closeSpelling(query, word))) return 4
    return Infinity
  }

  closeSpelling(query, word) {
    const allowedDistance = query.length <= 5 ? 1 : 2
    return Math.abs(query.length - word.length) <= allowedDistance && this.editDistance(query, word) <= allowedDistance
  }

  editDistance(left, right) {
    const previous = Array.from({ length: right.length + 1 }, (_, index) => index)
    for (let leftIndex = 1; leftIndex <= left.length; leftIndex += 1) {
      const current = [leftIndex]
      for (let rightIndex = 1; rightIndex <= right.length; rightIndex += 1) {
        const substitution = previous[rightIndex - 1] + (left[leftIndex - 1] === right[rightIndex - 1] ? 0 : 1)
        current[rightIndex] = Math.min(previous[rightIndex] + 1, current[rightIndex - 1] + 1, substitution)
      }
      previous.splice(0, previous.length, ...current)
    }
    return previous[right.length]
  }

  normalize(value) {
    return value.toString().normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().trim()
  }

  loadPeople() {
    const source = document.getElementById(this.sourceIdValue)
    return source ? JSON.parse(source.textContent) : []
  }

  renderResults() {
    this.resultsTarget.replaceChildren()
    this.matches.forEach((person, index) => {
      const option = document.createElement("button")
      option.type = "button"
      option.id = `${this.resultsTarget.id}_option_${person.id}`
      option.className = "motion-person-option"
      option.role = "option"
      option.dataset.personId = person.id
      option.ariaSelected = index === this.activeIndex ? "true" : "false"
      option.addEventListener("mousedown", (event) => event.preventDefault())
      option.addEventListener("click", (event) => this.choose(event))

      const name = document.createElement("strong")
      name.textContent = person.name
      const detail = document.createElement("span")
      detail.textContent = person.detail
      option.append(name, detail)
      this.resultsTarget.append(option)
    })

    const open = this.matches.length > 0
    this.resultsTarget.hidden = !open
    this.inputTarget.setAttribute("aria-expanded", open.toString())
    if (this.activeIndex >= 0) {
      const active = this.resultsTarget.children[this.activeIndex]
      this.inputTarget.setAttribute("aria-activedescendant", active.id)
      active.scrollIntoView({ block: "nearest" })
    } else {
      this.inputTarget.removeAttribute("aria-activedescendant")
    }
  }

  closeResults() {
    this.matches = []
    this.activeIndex = -1
    this.resultsTarget.hidden = true
    this.resultsTarget.replaceChildren()
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.inputTarget.removeAttribute("aria-activedescendant")
  }

  updateClearButton() {
    this.clearTarget.hidden = this.idTarget.value === "" && this.inputTarget.value === ""
  }

  updateValidity() {
    const unselectedText = this.inputTarget.value.trim() !== "" && this.idTarget.value === ""
    this.inputTarget.setCustomValidity(unselectedText ? "Choose a person from the roster results or clear this field." : "")
  }
}
