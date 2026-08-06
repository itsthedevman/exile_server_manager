import ApplicationController from "./application_controller";

// Copies a value to the clipboard and confirms it on the button itself. The toast system is server-rendered, and a
// copy never reaches the server, so the feedback has to be local to the click.
//
// Connects to data-controller="clipboard"
export default class extends ApplicationController {
  static targets = ["label"];

  static values = {
    text: String,
    copiedText: { type: String, default: "Copied" },
    resetDelay: { type: Number, default: 2000 },
  };

  connect() {
    this.idleLabel = this.labelElement.textContent;
  }

  disconnect() {
    super.disconnect();
    clearTimeout(this.timer);
    this.labelElement.textContent = this.idleLabel;
  }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.textValue);
    } catch {
      // The clipboard is unavailable outside a secure context and can be refused by permission. Reporting success
      // anyway would leave someone pasting whatever they copied last, so show the value instead and let them take
      // it by hand.
      this.flash(this.textValue);
      return;
    }

    this.flash(this.copiedTextValue);
  }

  flash(message) {
    this.labelElement.textContent = message;

    clearTimeout(this.timer);
    this.timer = setTimeout(() => {
      this.labelElement.textContent = this.idleLabel;
    }, this.resetDelayValue);
  }

  // Falls back to the button when no label target is declared, so a bare text button needs no extra markup.
  get labelElement() {
    return this.hasLabelTarget ? this.labelTarget : this.element;
  }
}
