import ApplicationController from "./application_controller";

// Keeps one vehicle's delivery fields answering only the questions that still apply.
//
// A territory is only worth picking for a vehicle headed into a garage, and a pin is only worth typing for a vehicle
// that has somewhere to land, so a player whose garages are all full is told that once rather than asked to fill in a
// code for a delivery that cannot happen. Hiding the picker also holds back its lazy frame, which is a round trip to
// the game server the player never needed.
//
// Connects to data-controller="reward-vehicle"
export default class extends ApplicationController {
  static targets = ["spawnLocation", "territoryField", "territory", "pinCode"];

  connect() {
    this.refresh();
  }

  // The picker arrives after the rest of the form does, and whether it came back empty is what decides the pin
  territoryTargetConnected() {
    this.refresh();
  }

  refresh() {
    const usesGarage = this.hasSpawnLocationTarget
      ? this.spawnLocationTarget.value === "virtual_garage"
      : this.hasTerritoryFieldTarget;

    if (this.hasTerritoryFieldTarget) {
      this.territoryFieldTarget.classList.toggle("d-none", !usesGarage);
    }

    // An unloaded picker is not an empty one, so the pin stays open until the frame says otherwise
    const noRoom =
      this.hasTerritoryTarget &&
      this.territoryTarget.dataset.empty === "true";

    if (this.hasTerritoryTarget) {
      this.territoryTarget.disabled = !usesGarage || noRoom;
    }

    const deliverable = !usesGarage || !noRoom;

    this.pinCodeTarget.disabled = !deliverable;
    this.pinCodeTarget.required = deliverable;
  }
}
