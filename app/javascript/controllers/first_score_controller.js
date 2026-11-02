import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["halftimeRoma", "halftimeOpponent", "fulltimeRoma", "fulltimeOpponent", "choice", "hint"]

  connect() { this.update() }

  update() {
    const fields = [this.halftimeRomaTarget, this.halftimeOpponentTarget, this.fulltimeRomaTarget, this.fulltimeOpponentTarget]
    const scores = fields.map(field => field.value === "" ? NaN : Number(field.value))
    const [hr, ho, fr, fo] = scores
    let automatic = null
    if (scores.every(score => Number.isInteger(score) && score >= 0) && hr <= fr && ho <= fo) {
      if (fr === 0 && fo === 0) automatic = "nobody"
      else if (fo === 0 || (hr > 0 && ho === 0)) automatic = "roma"
      else if (fr === 0 || (ho > 0 && hr === 0)) automatic = "opponent"
    }
    this.choiceTargets.forEach(choice => {
      choice.disabled = automatic !== null && choice.value !== automatic
      if (automatic !== null) choice.checked = choice.value === automatic
      if (automatic === null && this.previousAutomatic) choice.checked = false
      if (automatic === null && choice.value === "nobody") {
        choice.disabled = true
        choice.checked = false
      }
    })
    this.previousAutomatic = automatic
    this.hintTarget.textContent = automatic === null
      ? "По этому счёту первый гол не определяется. Выберите команду."
      : "Первый гол определён автоматически по счёту команд."
  }
}
