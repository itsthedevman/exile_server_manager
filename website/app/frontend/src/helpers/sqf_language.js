import { StreamLanguage } from "@codemirror/language";

// A compact SQF tokenizer for CodeMirror. SQF has no maintained CM6 grammar, and we don't need a full one here - this
// covers the shapes that make pasted code readable: comments, strings, numbers, the control keywords, and the local vs
// global variable split. Everything else falls through as a plain command identifier, which still reads fine.
//
// Token style names are the legacy CodeMirror mode names StreamLanguage maps to highlight tags ("keyword", "string",
// "comment", "number", "atom", "variable", "variable-2", "operator").

const KEYWORDS = new Set([
  "if", "then", "else", "exitwith", "while", "for", "from", "to", "step", "do", "foreach", "count", "switch", "case",
  "default", "with", "private", "params", "and", "or", "not", "call", "spawn", "waituntil", "scopename", "breakout",
  "breakto", "continue", "try", "catch", "throw", "isnil", "select", "in",
]);

const ATOMS = new Set([
  "true", "false", "nil", "objnull", "grpnull", "confignull", "controlnull", "displaynull", "locationnull",
  "scriptnull", "tasknull", "textnull",
]);

export const sqf = StreamLanguage.define({
  name: "sqf",

  startState() {
    return { inBlockComment: false };
  },

  token(stream, state) {
    if (state.inBlockComment) {
      if (stream.match(/.*?\*\//)) state.inBlockComment = false;
      else stream.skipToEnd();

      return "comment";
    }

    if (stream.eatSpace()) return null;

    if (stream.match("//")) {
      stream.skipToEnd();
      return "comment";
    }

    if (stream.match("/*")) {
      state.inBlockComment = true;
      return "comment";
    }

    const quote = stream.peek();
    if (quote === '"' || quote === "'") {
      stream.next();

      // SQF escapes a quote by doubling it ("" inside a "..." string), so a doubled quote continues the string.
      let ch;
      while ((ch = stream.next()) != null) {
        if (ch === quote && stream.peek() !== quote) break;
        if (ch === quote && stream.peek() === quote) stream.next();
      }

      return "string";
    }

    if (stream.match(/^0x[0-9a-fA-F]+/) || stream.match(/^\d*\.?\d+([eE][+-]?\d+)?/)) return "number";

    if (stream.match(/^[A-Za-z_][A-Za-z0-9_]*/)) {
      const word = stream.current().toLowerCase();

      if (KEYWORDS.has(word)) return "keyword";
      if (ATOMS.has(word)) return "atom";
      if (word.startsWith("_")) return "variable-2";

      return "variable";
    }

    if (stream.match(/^(>>|&&|\|\||[-+*/%=<>!^:]=?)/)) return "operator";

    stream.next();
    return null;
  },

  languageData: {
    commentTokens: { line: "//", block: { open: "/*", close: "*/" } },
  },
});
