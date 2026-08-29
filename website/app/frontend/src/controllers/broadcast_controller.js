import ApplicationController from "./application_controller";
import Markdown from "../helpers/markdown";

// Drives the broadcast modal: renders the message as Discord would, keeps the audience copy in step with the
// selector, and holds Send disabled until there is something to send.
//
// Every string the audience selector swaps in - the embed title, the recipient sentence - is rendered server-side
// onto the <option> and copied across here, so the wording lives in Ruby rather than being assembled twice.
//
// Connects to data-controller="broadcast"
export default class extends ApplicationController {
  static targets = ["audience", "counter", "idempotencyKey", "message", "preview", "previewTitle", "recipients", "submit"];

  connect() {
    this.messageChanged();
    this.audienceChanged();
  }

  messageChanged() {
    const message = this.messageTarget.value;
    const empty = message.trim().length === 0;

    this.counterTarget.textContent = message.length;

    // The footer carries a Send for mobile and another for desktop, so both move together.
    this.submitTargets.forEach((button) => {
      button.disabled = empty;
    });

    this.previewTarget.innerHTML = empty ? "Your message will appear here" : Markdown.toHTML(message);
  }

  audienceChanged() {
    const option = this.audienceTarget.selectedOptions[0];
    if (!option) return;

    this.recipientsTarget.textContent = option.dataset.summary;

    // Discord renders markdown in an embed's title, so the backticked server ids become code chips here the same way
    // they do in the DM. Its footer is plain text, which is why the preview's footer keeps its backticks literal.
    this.previewTitleTarget.innerHTML = Markdown.toHTML(option.dataset.previewTitle);
  }

  submitEnded({ detail: { success } }) {
    // Rotate only on success; a failed request keeps its key so a retry dedupes to the same row rather than sending
    // the whole player base a second copy.
    if (success) this.idempotencyKeyTarget.value = crypto.randomUUID();
  }
}
