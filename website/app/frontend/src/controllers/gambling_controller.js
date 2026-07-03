import ApplicationController from "./application_controller";

// Fills the bet input with a preset token (half/all) rather than submitting it,
// so a preset never fires an all-in bet on a single click. The player sees the
// value land in the box and clicks Gamble to commit.
//
// Connects to data-controller="gambling"
export default class extends ApplicationController {
  static targets = ["amount"];

  fill({ params }) {
    this.amountTarget.value = params.value;
    this.amountTarget.focus();
  }
}
