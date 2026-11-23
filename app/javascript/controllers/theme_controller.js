import { Controller } from "@hotwired/stimulus"
import { patch } from "@rails/request.js"

// Toggles the dark class, remembers the choice in localStorage so signed-out
// pages keep it, and stores it on the user when signed in.
export default class extends Controller {
  static values = { signedIn: Boolean }

  toggle() {
    const dark = !document.documentElement.classList.contains("dark")
    this.#apply(dark)

    localStorage.setItem("visualizer.theme", dark ? "dark" : "light")
    document.cookie = `browser.colorscheme=${dark ? "dark" : "light"}; path=/; max-age=31536000; samesite=lax`

    if (this.signedInValue) {
      patch("/theme", { body: { skin: dark ? "dark" : "light" }, responseKind: "json" })
    }
  }

  #apply(dark) {
    document.documentElement.classList.toggle("dark", dark)
    document.body?.classList.toggle("dark", dark)
    document.body?.classList.remove("light")
  }
}
