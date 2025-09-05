import ApplicationController from "./application_controller";
import * as bootstrap from "bootstrap";

// Connects to data-controller="toasts"
export default class extends ApplicationController {
  static targets = ["toast"];

  connect() {
    setTimeout(
      (toast) => {
        toast.hide();
      },
      7000,
      new bootstrap.Toast(this.toastTarget)
    );
  }
}
