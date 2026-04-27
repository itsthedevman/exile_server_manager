import ApplicationController from "./application_controller";
import * as bootstrap from "bootstrap";

// Connects to data-controller="auto-modal"
export default class extends ApplicationController {
  static values = {
    delay: { type: Number, default: 0 }, // Optional delay in milliseconds
    backdrop: { type: String, default: "true" }, // Bootstrap backdrop option
    keyboard: { type: Boolean, default: true }, // Bootstrap keyboard option
  };

  connect() {
    // Use nextTick to ensure DOM is fully ready
    this.nextTick(() => {
      this.openModal();
    });
  }

  openModal() {
    const modalElement = this.element;

    // Create/get the Bootstrap modal instance with custom options
    const modal = bootstrap.Modal.getOrCreateInstance(modalElement, {
      backdrop: this.backdropValue,
      keyboard: this.keyboardValue,
    });

    // Apply delay if specified
    if (this.delayValue > 0) {
      setTimeout(() => {
        modal.show();
      }, this.delayValue);
    } else {
      modal.show();
    }
  }
}
