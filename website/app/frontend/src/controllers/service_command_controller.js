import ApplicationController from "./application_controller";

// Polls a service command until it settles. The terminal response is a turbo
// stream that replaces this element, which removes the controller from the DOM
// and fires disconnect(), so the interval clears itself once we're done.
//
// Connects to data-controller="service-command"
export default class extends ApplicationController {
  static values = {
    url: String,
    interval: { type: Number, default: 1500 },
  };

  connect() {
    this.timer = setInterval(() => this.poll(), this.intervalValue);
  }

  disconnect() {
    super.disconnect();
    clearInterval(this.timer);
  }

  async poll() {
    const response = await fetch(this.urlValue, {
      headers: { Accept: "text/vnd.turbo-stream.html" },
      signal: this.abortController.signal,
    });

    // Still pending: the controller returns no content, so leave the spinner up.
    if (response.status === 204 || !response.ok) return;

    window.Turbo.renderStreamMessage(await response.text());
  }
}
