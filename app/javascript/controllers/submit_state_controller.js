import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.reset()
  }

  submit(event) {
    if (this.element.getAttribute("aria-busy") === "true") {
      event.preventDefault()
      return
    }
    this.element.setAttribute("aria-busy", "true")
    this.element.querySelectorAll('input[type="submit"], button[type="submit"]').forEach(button => {
      if (button.disabled) return
      button.dataset.submitStateOriginal = button.tagName === "INPUT" ? button.value : button.textContent
      button.dataset.submitStatePending = "true"
      button.disabled = true
      const label = button.dataset.turboSubmitsWith
      if (label) {
        if (button.tagName === "INPUT") button.value = label
        else button.textContent = label
      }
    })
  }

  reset() {
    this.element.removeAttribute("aria-busy")
    this.element.querySelectorAll('[data-submit-state-pending="true"]').forEach(button => {
      button.disabled = false
      if (button.tagName === "INPUT") button.value = button.dataset.submitStateOriginal
      else button.textContent = button.dataset.submitStateOriginal
      delete button.dataset.submitStatePending
      delete button.dataset.submitStateOriginal
    })
  }
}
