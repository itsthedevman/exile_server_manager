import ApplicationController from "./application_controller";

// Connects to data-controller="reward-contents-editor"
export default class extends ApplicationController {
  static targets = [
    "itemRows",
    "itemTemplate",
    "itemNote",
    "itemEmpty",
    "vehicleRows",
    "vehicleTemplate",
    "vehicleNote",
    "vehicleEmpty",
    "cooldownToggle",
    "cooldownFields",
    "cooldownDefaultHint",
    "cooldownQuantity",
    "currency",
    "emptyWarning",
  ];

  connect() {
    this.refresh();
  }

  addItem() {
    this.#append(this.itemRowsTarget, this.itemTemplateTarget);
  }

  addVehicle() {
    this.#append(this.vehicleRowsTarget, this.vehicleTemplateTarget);
  }

  remove(event) {
    event.currentTarget.closest("[data-reward-package-row]").remove();
    this.refresh();
  }

  refresh() {
    this.#showList(this.itemRowsTarget, this.itemNoteTarget, this.itemEmptyTarget);

    if (this.hasVehicleRowsTarget) {
      this.#showList(this.vehicleRowsTarget, this.vehicleNoteTarget, this.vehicleEmptyTarget);
    }

    // Only a package has one. A claim is contents and nothing else, so this half of the form is simply not there.
    if (this.hasCooldownToggleTarget) {
      const custom = this.cooldownToggleTarget.checked;

      this.cooldownFieldsTarget.hidden = !custom;
      this.cooldownDefaultHintTarget.hidden = custom;

      // A hidden field the browser is still required to validate refuses the submit with nothing to point at
      this.cooldownQuantityTarget.required = custom;
    }

    this.emptyWarningTarget.hidden = this.#holdsSomething();
  }

  // Mirrors ESM::ServerReward#rewards?, which is what decides whether the command will hand this package over
  #holdsSomething() {
    if (this.currencyTargets.some((field) => Number(field.value) > 0)) return true;
    if (this.itemRowsTarget.children.length > 0) return true;

    return this.hasVehicleRowsTarget && this.vehicleRowsTarget.children.length > 0;
  }

  //////////////////////////////////////////////////////////////////////////////

  #append(rows, template) {
    rows.appendChild(template.content.cloneNode(true));
    this.refresh();

    rows.lastElementChild?.querySelector("input")?.focus();
  }

  // The note explains what happens to what is in the list, so it has nothing to say about an empty one, which gets
  // an invitation to start it instead
  #showList(rows, note, empty) {
    const filled = rows.children.length > 0;

    note.hidden = !filled;
    empty.hidden = filled;
  }
}
