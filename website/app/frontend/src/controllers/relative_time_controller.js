import ApplicationController from "./application_controller";

// Renders a server timestamp as a live, relative "x ago" label and keeps it
// fresh while the page sits open. The exact time stays available on hover via
// the title attribute.
//
// Connects to data-controller="relative-time"
export default class extends ApplicationController {
  static values = {
    datetime: String,
    interval: { type: Number, default: 30000 },
  };

  connect() {
    this.date = new Date(this.datetimeValue);
    if (isNaN(this.date)) return;

    this.formatter = new Intl.RelativeTimeFormat(undefined, {
      numeric: "always",
    });
    this.element.title = this.date.toLocaleString();

    this.render();
    this.timer = setInterval(() => this.render(), this.intervalValue);
  }

  disconnect() {
    super.disconnect();
    clearInterval(this.timer);
  }

  render() {
    this.element.textContent = this.relativeLabel();
  }

  relativeLabel() {
    const seconds = Math.round((Date.now() - this.date.getTime()) / 1000);

    if (seconds < 60) return "just now";

    const units = [
      ["day", 86400],
      ["hour", 3600],
      ["minute", 60],
    ];

    for (const [unit, secondsPer] of units) {
      const value = Math.floor(seconds / secondsPer);
      if (value >= 1) return this.formatter.format(-value, unit);
    }
  }
}
