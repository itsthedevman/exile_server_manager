import ApplicationController from "./application_controller";

// Fills the bet input with a preset token (half/all) rather than submitting it,
// so a preset never fires an all-in bet on a single click. The player sees the
// value land in the box and clicks Gamble to commit.
//
// Also rotates the form's idempotency key after a bet's request succeeds. The
// server mints the first key; while a bet is in flight the key holds steady so a
// double-fire dedupes to one row, and only once the round-trip lands does the
// next bet get a fresh key. A dropped request keeps its key so a retry dedupes.
//
// Connects to data-controller="gambling"
export default class extends ApplicationController {
  static targets = ["amount", "idempotencyKey"];

  fill({ params }) {
    this.amountTarget.value = params.value;
    this.amountTarget.focus();
  }

  rotateKey({ detail: { success } }) {
    if (!success) return;

    this.idempotencyKeyTarget.value = crypto.randomUUID();
  }
}
