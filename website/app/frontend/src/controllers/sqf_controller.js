import ApplicationController from "./application_controller";

// Drives the SQF admin console: mounts a CodeMirror editor, feeds its content into the submitted form, and owns the
// Clear reset. The editor bundle is lazy-loaded on connect, so it only ships once an admin actually opens this card.
//
// The code and the resolved target ride in on the form's `formdata` event rather than mirrored hidden fields: the editor
// owns its content and the mode/uid controls own the target, so writing them straight into the outgoing FormData keeps a
// single source of truth. The idempotency key is a hidden field the server mints; it holds steady while a run is in
// flight (so a double-submit dedupes to one row) and rotates only once the round-trip lands.
//
// Connects to data-controller="sqf"
export default class extends ApplicationController {
  static targets = ["editor", "idempotencyKey", "mode", "playerField", "playerUid", "result"];

  async connect() {
    const [{ EditorView, basicSetup }, { oneDark }, { sqf }] = await Promise.all([
      import("codemirror"),
      import("@codemirror/theme-one-dark"),
      import("../helpers/sqf_language"),
    ]);

    // A slow import can resolve after Turbo already swapped this card away.
    if (!this.hasEditorTarget) return;

    // A fixed editor height makes the whole box a click target: CodeMirror stretches its content area to fill, so a
    // click anywhere below the last line lands the cursor on that line instead of doing nothing.
    const fillHeight = EditorView.theme({
      "&": { height: "15rem" },
      ".cm-scroller": { overflow: "auto" },
    });

    this.view = new EditorView({
      doc: "",
      extensions: [basicSetup, sqf, oneDark, EditorView.lineWrapping, fillHeight],
      parent: this.editorTarget,
    });
  }

  disconnect() {
    super.disconnect();
    this.view?.destroy();
  }

  fillFormData({ formData }) {
    // The command runs its own sanitization; just strip the surrounding whitespace so an empty submit is truly empty.
    formData.set("code_to_execute", this.view ? this.view.state.doc.toString().trim() : "");
    formData.set("target", this.resolvedTarget);
  }

  modeChanged() {
    this.playerFieldTarget.hidden = this.modeTarget.value !== "player";
  }

  // Resets the console to how it looks on a fresh page load: empty editor, result frame back to its prompt.
  clear() {
    this.view?.dispatch({
      changes: { from: 0, to: this.view.state.doc.length, insert: "" },
    });
    this.view?.focus();

    if (this.hasResultTarget) {
      this.resultTarget.innerHTML = '<div class="text-muted small text-center py-2">Run some SQF to see the output.</div>';
    }
  }

  rotateKey({ detail: { success } }) {
    if (!success) return;

    this.idempotencyKeyTarget.value = crypto.randomUUID();
  }

  get resolvedTarget() {
    if (this.modeTarget.value === "player") return this.playerUidTarget.value.trim();

    return this.modeTarget.value;
  }
}
