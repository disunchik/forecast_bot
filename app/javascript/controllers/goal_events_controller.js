import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "template"]

  connect() {
    this.index = this.listTarget.children.length
  }

  add() {
    const html = this.templateTarget.innerHTML.replaceAll("NEW_INDEX", this.index++)
    this.listTarget.insertAdjacentHTML("beforeend", html)
  }

  remove(event) {
    event.currentTarget.closest(".goal-row")?.remove()
  }
}
