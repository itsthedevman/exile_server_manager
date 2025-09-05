import ApplicationController from "./application_controller";
import $ from "../helpers/cash_dom";

// Connects to data-controller="confirm"
export default class extends ApplicationController {
  static values = {
    message: { type: String, default: "Are you sure?" },
  };

  connect() {
    $(this.element).on("click", this.confirm.bind(this));
  }

  confirm(event) {
    if (!confirm(this.messageValue)) {
      event.preventDefault();
      event.stopImmediatePropagation();
      return false;
    }
  }
}
