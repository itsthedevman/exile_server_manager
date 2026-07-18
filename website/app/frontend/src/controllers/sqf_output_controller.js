import ApplicationController from "./application_controller";

// Renders a returned SQF value as read-only, syntax-highlighted code. A command's return is itself valid SQF, so it gets
// the same highlighting as the editor - just without the editing chrome (no gutter, not editable). Lazy-loads CodeMirror
// the same way the editor does, reusing its already-cached chunk.
//
// Connects to data-controller="sqf-output"
export default class extends ApplicationController {
  static values = { code: String };

  async connect() {
    const [{ EditorView }, { EditorState }, { oneDark }, { sqf }] = await Promise.all([
      import("@codemirror/view"),
      import("@codemirror/state"),
      import("@codemirror/theme-one-dark"),
      import("../helpers/sqf_language"),
    ]);

    if (!this.element.isConnected) return;

    const cap = EditorView.theme({
      "&": { maxHeight: "20rem" },
      ".cm-scroller": { overflow: "auto" },
    });

    this.view = new EditorView({
      state: EditorState.create({
        doc: this.codeValue,
        extensions: [sqf, oneDark, EditorState.readOnly.of(true), EditorView.editable.of(false), EditorView.lineWrapping, cap],
      }),
      parent: this.element,
    });
  }

  disconnect() {
    super.disconnect();
    this.view?.destroy();
  }
}
