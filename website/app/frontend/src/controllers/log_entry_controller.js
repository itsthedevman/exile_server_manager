import ApplicationController from "./application_controller";
import $ from "../helpers/cash_dom";

// Connects to data-controller="log-entry"
export default class extends ApplicationController {
  static targets = ["row", "originalContent"];

  toggleOriginal(event) {
    const button = $(event.currentTarget);
    const lineNumber = button.data("logEntryRowParam");
    const row = this.findRowByLineNumber(lineNumber);

    if (!row || row.length === 0) return;

    const originalContent = row.find(
      '[data-log-entry-target="originalContent"]'
    );
    if (!originalContent || originalContent.length === 0) return;

    // Toggle visibility
    const isHidden = originalContent.hasClass("d-none");

    if (isHidden) {
      originalContent.show();
      button.text("×");
      button.attr("title", "Hide original log entry");
      button.removeClass("btn-outline-secondary");
      button.addClass("btn-outline-danger");
    } else {
      originalContent.hide();
      button.text("⋯");
      button.attr("title", "Show original log entry");
      button.removeClass("btn-outline-danger");
      button.addClass("btn-outline-secondary");
    }
  }

  findRowByLineNumber(lineNumber) {
    // Convert the DOM elements to cash-dom objects and find the matching one
    return $(this.rowTargets)
      .filter((_index, row) => {
        const $row = $(row);
        const button = $row.find(`[data-log-entry-row-param="${lineNumber}"]`);
        return button.length > 0;
      })
      .first();
  }
}
