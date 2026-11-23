import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["masked", "plain", "toggle", "copy"]

  toggle() {
    const reveal = this.plainTarget.classList.contains("hidden")

    this.plainTarget.classList.toggle("hidden", !reveal)
    this.maskedTarget.classList.toggle("hidden", reveal)
    this.toggleTarget.textContent = reveal ? "Hide" : "Reveal"
  }

  async copy() {
    await navigator.clipboard.writeText(this.plainTarget.textContent.trim())

    const original = this.copyTarget.textContent
    this.copyTarget.textContent = "Copied"
    setTimeout(() => {
      this.copyTarget.textContent = original
    }, 2000)
  }
}
