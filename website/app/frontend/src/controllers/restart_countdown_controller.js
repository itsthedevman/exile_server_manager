import ApplicationController from "./application_controller";

// Counts down to a server's next restart and keeps counting while the page sits open, so a sidebar left open for an
// hour doesn't keep claiming the restart is an hour away.
//
// Reported to the minute, not because the number deserves that precision, but because the status line above states
// uptime and the two are read together. Rounding this to one unit made 1h40m read as "1 hour" next to "online for
// about 1 hour", so a three hour restart interval looked like two.
//
// Connects to data-controller="restart-countdown"
export default class extends ApplicationController {
  static values = {
    datetime: String,
    interval: { type: Number, default: 30000 },
  };

  connect() {
    this.date = new Date(this.datetimeValue);
    if (isNaN(this.date)) return;

    this.element.title = this.date.toLocaleString();

    this.render();
    this.timer = setInterval(() => this.render(), this.intervalValue);
  }

  disconnect() {
    super.disconnect();
    clearInterval(this.timer);
  }

  render() {
    this.element.textContent = this.countdownLabel();
  }

  countdownLabel() {
    const minutes = Math.round((this.date.getTime() - Date.now()) / 60000);

    // Running past the estimate is the normal end state rather than an error, and nothing on this page re-renders
    // when the server comes back, so the label has to stay true while it waits to be reloaded.
    if (minutes < 1) return "any moment now";
    if (minutes < 60) return `in ${minutes}m`;

    const hours = Math.floor(minutes / 60);
    const remainder = minutes % 60;

    return remainder === 0 ? `in ${hours}h` : `in ${hours}h ${remainder}m`;
  }
}
