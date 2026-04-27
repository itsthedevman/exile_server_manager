import ApplicationController from "./application_controller";
import $ from "../helpers/cash_dom";
import * as R from "ramda";

// Connects to data-controller="rpt-parser"
export default class extends ApplicationController {
  static targets = [
    "fileInput",
    "fileName",
    "parseButton",
    "loadingCard",
    "resultsCard",
    "errorCard",
    "errorMessage",
    "errorCount",
    "errorsList",
    "successAlert",
    "removeDuplicates",
    "showExplanations",
  ];

  connect() {
    this.resetState();
    this.initializePatterns();
  }

  // ============================================================================
  // INITIALIZATION & STATE
  // ============================================================================

  resetState() {
    this.errors = [];
    this.rptLines = [];
  }

  initializePatterns() {
    this.patterns = {
      startOfError: /error in expression/i,
      errorPosition: /error position: <(.*)$/i,
      errorReason: /error\s(.*)$/i,

      errorInfos: [
        /file\s*.*,\s*line\s*\d+/i,
        /callextension.*could not be found/i,
      ],

      genericMessages: [
        /callextension .* could not be found$/i,
        /warning message: .* member already defined\.$/i,
        /warning message: .* missing '}'/i,
        /file .*: missing .*/i,
      ],
    };

    this.explanations = [
      {
        regex: /foreign error: unknown enum value: (.*)/gi,
        reason:
          "The enum value '<strong>$1</strong>' is not valid for this command.<br><strong>Quick fix:</strong> Check the <a href='https://community.bistudio.com/wiki' target='_blank'>Bohemia Wiki</a> for valid enum values, or double-check your spelling.",
      },
      {
        regex: /missing ;|missing '}'/gi,
        reason: `<strong>Missing punctuation detected!</strong><br>You're missing a <code>;</code> or <code>}</code> (or have an extra one) around this line.<br><strong>Pro tip:</strong> Arma throws this error for missing/extra: <code>( ) { } [ ]</code><br><strong>What to do:</strong> Check the lines around the error for matching brackets and semicolons.`,
      },
      {
        regex: /invalid number in expression/gi,
        reason:
          "<strong>Expected a number, got something else!</strong><br>A variable or command parameter should be a number but isn't valid.<br><strong>What to check:</strong> Make sure variables contain actual numbers, not strings or nil values.",
      },
      {
        regex: /generic error in expression/gi,
        reason: `<strong>Bohemia's way of saying "¯\\_(ツ)_/¯"</strong><br>This is one of the trickiest errors - the engine knows something's wrong but can't pinpoint what.<br><strong>Debug strategy:</strong> Check syntax around the reported line, look for typos in command names, and verify all brackets match.`,
      },
      {
        regex: /callextension '(.*)' could not be found/i,
        reason:
          "Missing DLL file: <strong>$1</strong><br><strong>What's needed:</strong><br>• <code>$1.dll</code> and/or <code>$1_x64.dll</code> in your server folder<br>• Make sure the DLL name spelling is exactly right<br>• Check that the mod containing this DLL is loaded",
      },
      {
        regex: /undefined variable in expression: (.*)/i,
        reason: `<strong>Variable '<code>$1</code>' doesn't exist!</strong><br><strong>Common causes:</strong><br>• Variable was never initialized (missing <code>$1 = something;</code>)<br>• Variable was set to <code>nil</code><br>• Missing parameter when calling a script<br>• Typo in variable name`,
      },
      {
        regex: /warning message: (.*): \.(.*): member already defined\.$/i,
        reason:
          "Duplicate class definition in <strong>$1</strong><br>The class <code>$2</code> is defined twice in this file.<br><strong>Check for:</strong><br>• Duplicate class definitions<br>• Files included with <code>#include</code> that also define this class",
      },
      {
        regex: /warning message: (.*) missing '}'/i,
        reason:
          "Bracket mismatch in <strong>$1</strong><br><strong>Common issues:</strong><br>• Missing <code>}</code> somewhere before this line<br>• Extra <code>};</code> (semicolon after closing bracket)<br>• Mismatched opening/closing brackets",
      },
      {
        regex: /File (.*), line (.*): '(.*)': missing '(.*)' prior '(.*)'/i,
        reason:
          "Config syntax error in <strong>$1</strong> around line <strong>$2</strong><br>The config entry <code>$3</code> is missing <code>$4</code> before <code>$5</code><br><strong>Quick fix:</strong> Add the missing punctuation where indicated.",
      },
    ];
  }

  // ============================================================================
  // EVENT HANDLERS
  // ============================================================================

  onFileSelected(event) {
    const file = R.head(event.target.files);

    if (file) {
      $(this.fileNameTarget).text(`Selected: ${file.name}`);
      $(this.parseButtonTarget).prop("disabled", false);
    } else {
      $(this.fileNameTarget).text("No file selected");
      $(this.parseButtonTarget).prop("disabled", true);
    }
  }

  async parseFile() {
    const file = R.head(this.fileInputTarget.files);

    if (!file) {
      this.showError("Please select an RPT file to parse");
      return;
    }

    this.showLoading();

    try {
      await this.processFile(file);
      this.showResults();
    } catch (error) {
      console.error("Error processing file:", error);
      this.showError(`Error reading file: ${error.message}`);
    }
  }

  reset() {
    $(this.fileInputTarget).val("");
    $(this.fileNameTarget).text("No file selected");
    $(this.parseButtonTarget).prop("disabled", true);
    $(this.resultsCardTarget).addClass("d-none");
    $(this.errorCardTarget).addClass("d-none");
    this.resetState();
  }

  // ============================================================================
  // FILE PROCESSING
  // ============================================================================

  async processFile(file) {
    const fileContent = await this.readFile(file);
    this.rptLines = fileContent.split(/\r\n|\n/);

    if (R.isEmpty(this.rptLines)) {
      throw new Error("Failed to read RPT file");
    }

    this.parseRPT();

    if ($(this.removeDuplicatesTarget).is(":checked")) {
      this.filterDuplicates();
    }

    if ($(this.showExplanationsTarget).is(":checked")) {
      this.addExplanations();
    }
  }

  parseRPT() {
    let inError = false;
    let currentError = this.createEmptyError();
    let lineCount = 0;

    this.errors = [];

    R.addIndex(R.forEach)((line, index) => {
      lineCount++;

      if (!inError) {
        this.checkGenericMessages(line, index + 1);
      }

      if (!inError && this.patterns.startOfError.test(line)) {
        currentError = this.createEmptyError(index + 1);
        inError = true;
        lineCount = 0;
        return;
      }

      if (inError) {
        if (lineCount >= 30) {
          this.errors.push(currentError);
          inError = false;
          return;
        }

        if (this.processErrorLine(line, currentError)) {
          this.errors.push(currentError);
          inError = false;
        }
      }
    }, this.rptLines);
  }

  checkGenericMessages(line, lineNumber) {
    R.forEach((pattern) => {
      const match = pattern.exec(line);
      if (match) {
        this.errors.push({
          code: "",
          reason: "",
          info: match[0],
          rptLine: lineNumber,
          explanation: "",
        });
      }
    }, this.patterns.genericMessages);
  }

  processErrorLine(line, currentError) {
    const positionMatch = this.patterns.errorPosition.exec(line);
    if (positionMatch) {
      currentError.code = positionMatch[1];
      return false;
    }

    const reasonMatch = this.patterns.errorReason.exec(line);
    if (reasonMatch) {
      currentError.info = reasonMatch[1];
      return false;
    }

    return R.any((regex) => {
      const match = regex.exec(line);
      if (match) {
        currentError.reason = match[0];
        return true;
      }
      return false;
    }, this.patterns.errorInfos);
  }

  // ============================================================================
  // ERROR ENHANCEMENT
  // ============================================================================

  filterDuplicates() {
    const normalizeError = (error) => {
      const parts = [];
      if (error.code?.trim()) parts.push(`code:${error.code.trim()}`);
      if (error.info?.trim()) parts.push(`info:${error.info.trim()}`);
      if (error.reason?.trim()) parts.push(`reason:${error.reason.trim()}`);

      return parts.join("|");
    };

    const seen = new Set();
    this.errors = this.errors.filter((error) => {
      const signature = normalizeError(error);
      if (signature && seen.has(signature)) {
        return false;
      }
      if (signature) seen.add(signature);
      return true;
    });
  }

  addExplanations() {
    this.errors = R.map((error) => {
      const explanation = this.findExplanation(error.info);
      const enhancedError = explanation
        ? R.assoc("explanation", explanation, error)
        : error;

      return this.enhanceErrorContext(enhancedError);
    }, this.errors);
  }

  findExplanation(info) {
    return R.reduce(
      (acc, explanationData) => {
        if (acc) return acc;

        const regex = new RegExp(
          explanationData.regex.source,
          explanationData.regex.flags
        );
        const match = regex.exec(info);

        if (match) {
          return Array.isArray(match)
            ? match[0].replace(regex, explanationData.reason)
            : explanationData.reason;
        }

        return null;
      },
      null,
      this.explanations
    );
  }

  enhanceErrorContext(error) {
    let enhanced = { ...error };

    // Extract file info for header display
    const fileMatch = error.reason?.match(/File (.*?),?\s*line\s*(\d+)/i);
    if (fileMatch) {
      enhanced.fileName = fileMatch[1].replace(/\.\.\.$/, "");
      enhanced.lineNumber = fileMatch[2];
      enhanced.fileReference = `${enhanced.fileName}:${enhanced.lineNumber}`;
    }

    // Only warnings get yellow, everything else is critical
    if (error.info?.toLowerCase().includes("warning message")) {
      enhanced.severity = "warning";
      enhanced.severityLabel = "Warning";
    } else {
      enhanced.severity = "critical";
      enhanced.severityLabel = "Critical";
    }

    return enhanced;
  }

  // ============================================================================
  // UI STATE MANAGEMENT
  // ============================================================================

  showLoading() {
    $(this.loadingCardTarget).removeClass("d-none");
    $(this.resultsCardTarget).addClass("d-none");
    $(this.errorCardTarget).addClass("d-none");
  }

  hideLoading() {
    $(this.loadingCardTarget).addClass("d-none");
  }

  showError(message) {
    $(this.errorMessageTarget).text(message);
    $(this.errorCardTarget).removeClass("d-none");
    $(this.loadingCardTarget).addClass("d-none");
    $(this.resultsCardTarget).addClass("d-none");
  }

  showResults() {
    this.hideLoading();
    $(this.resultsCardTarget).removeClass("d-none");

    const errorCount = this.errors.length;

    if (errorCount === 0) {
      $(this.successAlertTarget).removeClass("d-none");
      $(this.errorCountTarget).text("No errors found! 🎉");
      $(this.errorsListTarget).html("");
    } else {
      $(this.successAlertTarget).addClass("d-none");
      $(this.errorCountTarget).text(
        `${errorCount} error${errorCount !== 1 ? "s" : ""} found`
      );
      this.renderErrors();
    }
  }

  // ============================================================================
  // ERROR RENDERING
  // ============================================================================

  renderErrors() {
    const errorHtml = R.addIndex(R.map)(
      (error, index) => this.createErrorCard(error, index + 1),
      this.errors
    ).join("");

    $(this.errorsListTarget).html(errorHtml);
  }

  createErrorCard(error, index) {
    const severityColor = error.severity === "warning" ? "warning" : "danger";

    return `
      <div class="col-lg-6">
        <div class="card h-100 bg-${severityColor} bg-opacity-10 border-${severityColor}">
          <div class="card-header border-${severityColor}">
            <div class="d-flex align-items-center justify-content-between">
              <h6 class="mb-0 text-${severityColor}">
                <i class="bi bi-exclamation-triangle me-2"></i>
                Error #${index} <small class="text-muted">Line ${
      error.rptLine
    }</small>
              </h6>
              ${
                error.severityLabel
                  ? `<span class="badge bg-${severityColor}">${error.severityLabel}</span>`
                  : ""
              }
            </div>
            ${
              error.fileReference
                ? `
                  <small class="text-muted mt-1 d-block font-monospace">
                    ${error.fileReference}
                    <i class="bi bi-clipboard me-1" style="cursor: pointer;" onclick="navigator.clipboard.writeText('${error.fileReference}')" title="Copy to clipboard"></i>
                  </small>
                `
                : ""
            }
          </div>
          <div class="card-body d-flex flex-column">
            <div class="flex-fill">
              ${this.renderErrorCode(error.code)}
            </div>

            <div class="mt-auto">
              ${this.renderErrorExplanation(error.explanation)}
              ${this.renderErrorInfo(error.info)}
              ${this.renderErrorReason(error.reason)}
            </div>
          </div>
        </div>
      </div>
    `;
  }

  renderErrorCode(code) {
    return code
      ? `
      <div class="mb-3">
        <strong class="text-light">Code:</strong>
        <div class="bg-dark p-2 rounded mt-1">
          <code class="text-warning">${this.escapeHtml(code)}</code>
        </div>
      </div>
    `
      : "";
  }

  renderErrorInfo(info) {
    return info
      ? `
      <div class="mb-2">
        <strong class="text-light">Info:</strong>
        <p class="text-muted mt-1 mb-0 small">${this.escapeHtml(info)}</p>
      </div>
    `
      : "";
  }

  renderErrorReason(reason) {
    if (!reason) return "";

    // Strip redundant file path info since we show it in the header
    const cleanedReason = reason
      .replace(/^File\s+.*?,?\s*line\s*\d+:?\s*/i, "")
      .trim();

    // Skip if empty or too short after cleaning
    if (!cleanedReason || cleanedReason.length < 10) return "";

    return `
      <div class="mb-0">
        <strong class="text-light">Reason:</strong>
        <p class="text-muted mt-1 mb-0 small">${this.escapeHtml(
          cleanedReason
        )}</p>
      </div>
    `;
  }

  renderErrorExplanation(explanation) {
    return explanation
      ? `
      <div class="alert alert-info bg-info bg-opacity-10 border-info mb-3">
        <h6 class="text-info mb-2">
          <i class="bi bi-lightbulb me-2"></i>
          Explanation:
        </h6>
        <div class="small">${explanation}</div>
      </div>
    `
      : "";
  }

  // ============================================================================
  // UTILITIES
  // ============================================================================

  createEmptyError(lineNumber = 0) {
    return {
      code: "",
      reason: "",
      info: "",
      rptLine: lineNumber,
      explanation: "",
    };
  }

  readFile(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = (event) => resolve(event.target.result);
      reader.onerror = () => reject(new Error("Failed to read file"));
      reader.readAsText(file);
    });
  }

  escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }
}
