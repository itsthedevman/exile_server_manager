import ApplicationController from "./application_controller";
import * as R from "ramda";
import $ from "../helpers/cash_dom";

// Connects to data-controller="additional-logs"
export default class extends ApplicationController {
  static targets = ["emptyState", "pathsContainer", "pathsList", "pathCount"];
  static values = { paths: Array };

  connect() {
    this.paths = R.clone(this.pathsValue);
    this.#renderPaths();
  }

  add(_event) {
    this.paths.push("");
    this.#renderPaths();
  }

  update(event) {
    const elem = $(event.currentTarget);
    const index = parseInt(elem.data("index"));

    this.paths[index] = elem.val();
  }

  remove(event) {
    const index = parseInt($(event.currentTarget).data("pathIndex"));
    this.paths.splice(index, 1);
    this.#renderPaths();
  }

  //////////////////////////////////////////////////////////////////////////////

  #createPathRow(path, index) {
    return `
      <tr>
        <td class="col-11">
          <input
            type="text"
            class="form-control form-control-sm font-monospace"
            name="server[server_settings][additional_logs][]"
            placeholder="logs/custom.log or /full/path/to/log.log"
            value="${path}"
            data-action="input->additional-logs#update"
            data-index="${index}"
          >
        </td>
        <td class="col">
          <button
            type="button"
            class="btn btn-outline-danger btn-sm w-100"
            data-action="click->additional-logs#remove"
            data-path-index="${index}"
            title="Remove log path"
          >
            <i class="bi bi-trash"></i>
          </button>
        </td>
      </tr>
    `;
  }

  #renderPaths() {
    const emptyStateElem = $(this.emptyStateTarget);
    const pathsContainerElem = $(this.pathsContainerTarget);
    const pathsListElem = $(this.pathsListTarget);
    const pathCountElem = $(this.pathCountTarget);
    const pathLength = this.paths.length;

    if (pathLength === 0) {
      emptyStateElem.show();
      pathsContainerElem.hide();
      pathsListElem.html("");
      pathCountElem.text("0");
    } else {
      emptyStateElem.hide();
      pathsContainerElem.show();
      pathCountElem.text(pathLength);

      pathsListElem.html("");
      this.paths.forEach((path, index) => {
        const pathRow = this.#createPathRow(path, index);
        pathsListElem.append(pathRow);
      });
    }
  }
}
