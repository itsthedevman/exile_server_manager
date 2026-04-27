import ApplicationController from "./application_controller";

export default class extends ApplicationController {
  submit(_event) {
    this.element.requestSubmit();
  }
}
