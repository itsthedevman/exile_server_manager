import ApplicationController from "./application_controller";

// Mirrors ESM::Regex::STEAM_UID_ONLY (core/lib/esm/regex.rb). Kept just as loose as the server's check so the client
// never blocks a uid the SQF command would have accepted; if that pattern tightens, tighten this alongside it.
const STEAM_UID_PATTERN = /^7656\d+$/;

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
  static targets = ["editor", "idempotencyKey", "mode", "playerField", "playerUid", "result", "resultSection", "submit"];

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
      "&": { height: "20rem" },
      ".cm-scroller": { overflow: "auto" },
    });

    // Keep the Run button's enabled state in step with the editor as the admin types.
    const syncOnChange = EditorView.updateListener.of((update) => {
      if (update.docChanged) this.syncSubmitState();
    });

    this.view = new EditorView({
      doc: "",
      extensions: [basicSetup, sqf, oneDark, EditorView.lineWrapping, fillHeight, syncOnChange],
      parent: this.editorTarget,
    });

    this.syncSubmitState();
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
    this.syncPlayerValidity();
    this.syncResultSection();
    this.syncSubmitState();
  }

  // Fires on every keystroke in the Steam UID field: refresh the inline invalid state, then the Run button.
  playerUidChanged() {
    this.syncPlayerValidity();
    this.syncSubmitState();
  }

  // Run stays disabled until the request is actually complete: there's code to run, and - for a Specific-player run - a
  // well-formed Steam UID to run it on. Nothing gets sent (nor the button enabled) before then.
  syncSubmitState() {
    if (!this.hasSubmitTarget) return;

    const hasCode = this.view ? this.view.state.doc.toString().trim().length > 0 : false;

    this.submitTarget.disabled = !(hasCode && this.hasValidTarget);
  }

  // Flags the uid field invalid once the admin has typed something that isn't a Steam UID. An empty field stays neutral
  // - the disabled Run button already carries the "not ready yet" signal, so we don't scold before they've typed a uid.
  syncPlayerValidity() {
    if (!this.hasPlayerUidTarget) return;

    const value = this.playerUidTarget.value.trim();
    const invalid = this.modeTarget.value === "player" && value.length > 0 && !STEAM_UID_PATTERN.test(value);

    this.playerUidTarget.classList.toggle("is-invalid", invalid);
  }

  // The output section only earns its space for the server-process target, where a run can return a value. While idle it
  // stays hidden for All/Specific-player runs; a run that fails reveals it again (see submitEnded) so the error surfaces.
  syncResultSection() {
    if (this.hasResultSectionTarget) this.resultSectionTarget.hidden = this.modeTarget.value !== "server";
  }

  // Resets the console to how it looks on a fresh page load: empty editor, result frame back to its idle prompt.
  clear() {
    this.view?.dispatch({changes: { from: 0, to: this.view.state.doc.length, insert: "" }});
    this.view?.focus();

    if (this.hasPlayerUidTarget) this.playerUidTarget.value = "";

    if (this.hasResultTarget) {
      this.resultTarget.innerHTML = '<div class="text-muted small text-center py-2">Run some SQF to see the output.</div>';
    }

    this.syncPlayerValidity();
    this.syncResultSection();
    this.syncSubmitState();
  }

  submitEnded({ detail: { success } }) {
    // Reveal the outcome no matter the target: a denial or an execution error has to show even for All/Specific-player,
    // where the section is otherwise hidden while idle.
    if (this.hasResultSectionTarget) this.resultSectionTarget.hidden = false;

    // Rotate only on success; a failed request keeps its key so a retry dedupes to the same row.
    if (success) this.idempotencyKeyTarget.value = crypto.randomUUID();
  }

  // A Specific-player run needs a well-formed Steam UID; Server/All carry their target in the mode value itself.
  get hasValidTarget() {
    if (this.modeTarget.value !== "player") return true;

    return STEAM_UID_PATTERN.test(this.playerUidTarget.value.trim());
  }

  get resolvedTarget() {
    if (this.modeTarget.value === "player") return this.playerUidTarget.value.trim();

    return this.modeTarget.value;
  }
}
