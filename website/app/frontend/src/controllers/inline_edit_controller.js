import ApplicationController from "./application_controller";

// Connects to data-controller="inline-edit"
// Swaps a display view for an edit form in place: the trigger reveals the form and focuses its
// input; cancel (button or Escape) restores the display. `open` starts in the edit state, used
// when the server re-renders the widget after a failed submit so the field keeps focus.
export default class extends ApplicationController {
  static targets = ["display", "form", "input"];
  static values = { open: Boolean, current: String };

  connect() {
    if (this.openValue) this.#open();
  }

  edit() {
    this.#open();
  }

  submit(event) {
    // Unchanged from the saved value - close without bothering the server.
    if (this.inputTarget.value === this.currentValue) {
      event.preventDefault();
      this.cancel();
    }
  }

  cancel() {
    this.formTarget.classList.add("d-none");
    this.displayTarget.classList.remove("d-none");
  }

  #open() {
    this.displayTarget.classList.add("d-none");
    this.formTarget.classList.remove("d-none");
    this.inputTarget.focus();
    this.inputTarget.select();
  }
}
