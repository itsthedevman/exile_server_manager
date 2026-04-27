import DOMPurify from "dompurify";
import { marked } from "marked";

export default class Markdown {
  static toHTML(markdown) {
    const html = marked.parse(markdown);

    return DOMPurify.sanitize(html, {
      USE_PROFILES: { html: true },
      FORBID_TAGS: ["p", "h4", "h5", "h6"],
    });
  }
}
