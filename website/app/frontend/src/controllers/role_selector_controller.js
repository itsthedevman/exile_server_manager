import ApplicationController from "./application_controller";
import Choices from "choices.js";
import "choices.js/public/assets/styles/choices.css";

// Connects to data-controller="role-selector"
export default class extends ApplicationController {
  static values = { id: String };

  connect() {
    const element = this.element;
    if (element.classList.contains("choices__input")) return;

    const rolesJSON = element.dataset.roles;
    if (rolesJSON == null || rolesJSON.length === 0) return;

    const roles = JSON.parse(rolesJSON);
    this.choices = new Choices(element, {
      choices: roles,
      allowHTML: true,
      removeItemButton: true,
      placeholderValue: "  Search for roles to add...",
    });
  }

  // Controller->Controller event
  handleEnableChange({ detail: { enabled, targetId } }) {
    if (this.choices == null || this.idValue != targetId) return;

    if (enabled) {
      this.choices.enable();
    } else {
      this.choices.disable();
    }
  }
}
