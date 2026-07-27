import ApplicationController from "./application_controller";
import * as bootstrap from "bootstrap";

// Connects to data-controller="reset-confirm"
// Closes the reset-all modal once its form actually starts submitting. A data-bs-dismiss on the submit button would
// swallow the submission, so the modal is dismissed on turbo:submit-start instead.
export default class extends ApplicationController {
  close() {
    bootstrap.Modal.getOrCreateInstance(this.element).hide();
  }
}
