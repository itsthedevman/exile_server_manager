import ApplicationController from "./application_controller";

// Connects to data-controller="reward-claim-filters"
//
// Narrows the claims table in the browser. A player holds at most one claim per server and a delivered claim is
// deleted outright, so the page arrives holding the whole set and filtering only has to mean hiding what does not
// match. Nothing here navigates.
export default class extends ApplicationController {
  static targets = ["row", "empty", "reset"];

  connect() {
    this.apply();
  }

  filter() {
    this.apply();
  }

  reset() {
    this.select(this.playerField(), "");
    this.select(this.serverField(), "");
    this.select(this.stateField(), "");
  }

  // An empty table renders neither the rows nor the selects the rest of this reads, so there is nothing to narrow.
  apply() {
    if (this.rowTargets.length === 0) return;

    const wanted = this.selection();
    let showing = 0;

    this.rowTargets.forEach((row) => {
      const matches = Object.entries(wanted).every(
        ([field, value]) => value === "" || row.dataset[field] === value,
      );

      row.hidden = !matches;
      if (matches) showing += 1;
    });

    this.emptyTarget.hidden = showing !== 0;
    this.resetTarget.hidden = Object.values(wanted).every((value) => value === "");
  }

  // Setting select.value alone would filter correctly and leave the visible control still reading "Any player":
  // SlimSelect draws its own markup and only redraws when told, so the change has to go through it.
  select(field, value) {
    this.setSlimSelected(field, value || "", false);
  }

  selection() {
    return {
      player: this.playerField().value,
      server: this.serverField().value,
      state: this.stateField().value,
    };
  }

  playerField() {
    return this.element.querySelector("[name='player']");
  }

  serverField() {
    return this.element.querySelector("[name='server']");
  }

  stateField() {
    return this.element.querySelector("[name='state']");
  }
}
