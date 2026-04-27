import ApplicationController from "./application_controller";
import * as bootstrap from "bootstrap";

// Connects to data-controller="collapse-toggle"
export default class extends ApplicationController {
  static values = {
    defaultText: String,
    activeText: String,
    show: Boolean,
    target: String,
  };

  connect() {
    this.element.textContent = this.defaultTextValue;
    this.isExpanded = false;

    if (this.showValue) {
      this.toggle();
    }
  }

  toggle() {
    this.isExpanded = !this.isExpanded;

    this.element.textContent = this.isExpanded
      ? this.activeTextValue
      : this.defaultTextValue;

    const collapse = bootstrap.Collapse.getOrCreateInstance(this.targetValue);
    collapse.toggle();
  }
}
