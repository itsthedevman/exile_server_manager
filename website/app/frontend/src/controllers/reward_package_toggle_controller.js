import ApplicationController from "./application_controller";

// A switch that lives inside the server form, so it cannot be a form of its own. The request goes out by hand and
// the response is the package list, re-rendered from what was actually stored.
//
// Connects to data-controller="reward-package-toggle"
export default class extends ApplicationController {
  static values = { url: String };

  async toggle(event) {
    const input = event.currentTarget;
    input.disabled = true;

    const response = await fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content,
      },
      signal: this.abortController.signal,
    });

    // The list never came back, so the switch is showing something that did not happen
    if (!response.ok) {
      input.checked = !input.checked;
      input.disabled = false;
      return;
    }

    window.Turbo.renderStreamMessage(await response.text());
  }
}
