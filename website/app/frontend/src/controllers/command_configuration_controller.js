import ApplicationController from "./application_controller";
import $ from "../helpers/cash_dom";
import { isChecked } from "../helpers/forms";

// Connects to data-controller="command-configuration"
export default class extends ApplicationController {
  static targets = [
    "enable",
    "notifyWhenDisabled",
    "allowInTextChannels",
    "allowlistEnabled",
    "allowlistedRoleIds",
    "cooldownQuantity",
    "cooldownType",
  ];

  static values = { id: String };

  connect() {
    this.nextTick(() => this.#setup());
  }

  onEnableClicked(event) {
    this.#toggleForm(isChecked(event.currentTarget));
  }

  onAllowlistEnableClicked(event) {
    this.#toggleAllowlist(isChecked(event.currentTarget));
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////

  #setup() {
    if (!this.hasEnableTarget) return;

    const commandEnabled = isChecked(this.enableTarget);

    // This will cause a race condition with the next toggle
    // Plus, the elements are already enabled by default
    if (!commandEnabled) {
      this.#toggleForm(commandEnabled);
    }

    if (commandEnabled && this.hasAllowlistEnabledTarget) {
      this.#toggleAllowlist(isChecked(this.allowlistEnabledTarget));
    }
  }

  #toggleAllowlist(enabled) {
    if (!this.hasAllowlistedRoleIdsTarget) return;

    $(this.allowlistedRoleIdsTarget).prop("disabled", !enabled);

    this.dispatch("enableChanged", {
      detail: { enabled, targetId: this.idValue },
    });
  }

  #toggleForm(enabled) {
    if (this.hasAllowInTextChannelsTarget) {
      $(this.allowInTextChannelsTarget).prop("disabled", !enabled);
    }

    if (this.hasAllowlistEnabledTarget) {
      $(this.allowlistEnabledTarget).prop("disabled", !enabled);
    }

    if (this.hasCooldownQuantityTarget) {
      $(this.cooldownQuantityTarget).prop("disabled", !enabled);
    }

    if (this.hasCooldownTypeTarget) {
      $(this.cooldownTypeTarget).prop("disabled", !enabled);
    }

    this.#toggleAllowlist(enabled);
  }
}
