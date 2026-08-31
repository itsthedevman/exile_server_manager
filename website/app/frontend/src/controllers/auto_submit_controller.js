import ApplicationController from "./application_controller";

export default class extends ApplicationController {
  submit(_event) {
    this.element.requestSubmit();
  }

  // For a control that sits outside the form it belongs to, associated by the form attribute rather than by nesting.
  // A form cannot be nested inside another one, so a control that has to appear inside a second form's markup is
  // placed there and pointed back at its own. Its form owner is what submits, not the element this sits on.
  submitOwner(_event) {
    this.element.form?.requestSubmit();
  }
}
