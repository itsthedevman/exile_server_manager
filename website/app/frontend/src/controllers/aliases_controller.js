import ApplicationController from "./application_controller";
import * as R from "ramda";
import $ from "../helpers/cash_dom";
import * as bootstrap from "bootstrap";
import { Serializer } from "../helpers/forms";

// Connects to data-controller="aliases"
export default class extends ApplicationController {
  static targets = ["placeholder", "emptyState", "container", "count"];
  static values = { data: Object };

  connect() {
    this.serializer = new Serializer(
      "div[data-controller='aliases']",
      "user[aliases]"
    );

    this.aliases = R.clone(this.dataValue);
    this.#renderAliases();
  }

  set({ detail: { id, server, community, value } }) {
    this.aliases[id] = { id, server, community, value };
    this.#renderAliases();
  }

  edit(event) {
    const id = $(event.currentTarget).data("id");

    const alias = this.aliases[id];
    this.dispatch("edit", { detail: { alias } });

    bootstrap.Modal.getOrCreateInstance("#edit_alias_modal").show();
  }

  delete(event) {
    const id = $(event.currentTarget).data("id");
    delete this.aliases[id];

    this.#renderAliases();
  }

  //////////////////////////////////////////////////////////////////////////////

  #createAliasCard(alias, id) {
    const isServer = alias.server !== null;
    const entity = isServer ? alias.server : alias.community;
    const badgeClass = isServer ? "bg-success" : "bg-primary";

    const iconClass = isServer
      ? "bi-server text-success"
      : "bi-discord text-primary";

    const entityName = isServer ? entity.server_name : entity.community_name;
    const entityId = isServer ? entity.server_id : entity.community_id;

    return `
    <div class="card bg-dark border-secondary">
      <div class="card-body">
        <div class="row align-items-center">
          <div class="col-2">
            <span class="badge fs-6 px-3 py-2 font-monospace text-wrap text-break ${badgeClass}">
              ${alias.value}
            </span>
          </div>
          <div class="col">
            <div class="d-flex align-items-center">
              <i class="bi ${iconClass} fs-4 me-3"></i>
              <div>
                <div class="text-light fw-medium">${entityName}</div>
                <small class="text-muted">${entityId}</small>
              </div>
            </div>
          </div>

          <!-- Mobile -->
          <div class="col-12 d-lg-none mt-3">
            <div class="row g-2">
              <div class="col-6">
                <button class="btn btn-outline-primary btn-sm w-100"
                        type="button"
                        title="Edit alias"
                        data-action="click->aliases#edit"
                        data-id="${id}">
                  <i class="bi bi-pencil me-1"></i>Edit
                </button>
              </div>
              <div class="col-6">
                <button class="btn btn-outline-danger btn-sm w-100"
                        type="button"
                        title="Delete alias"
                        data-action="click->aliases#delete"
                        data-id="${id}">
                  <i class="bi bi-trash me-1"></i>Delete
                </button>
              </div>
            </div>
          </div>

          <!-- Desktop -->
          <div class="col-2 d-none d-lg-block">
            <div class="d-flex gap-1 justify-content-end">
              <button class="btn btn-outline-primary btn-sm"
                      type="button"
                      title="Edit alias"
                      data-action="click->aliases#edit"
                      data-id="${id}">
                <i class="bi bi-pencil"></i>
              </button>
              <button class="btn btn-outline-danger btn-sm"
                      type="button"
                      title="Delete alias"
                      data-action="click->aliases#delete"
                      data-id="${id}">
                <i class="bi bi-trash"></i>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  `;
  }

  #renderAliases() {
    const emptyStateElem = $(this.emptyStateTarget);
    const containerElem = $(this.containerTarget);
    const countElem = $(this.countTarget);

    const aliases = R.values(this.aliases);
    const length = aliases.length;

    // Clean up the data
    let serializedData = aliases.map((alias) => {
      alias = R.omit(["id", "type"], alias);
      alias.community_id = alias.community?.community_id;
      alias.server_id = alias.server?.server_id;
      return R.omit(["server", "community"], alias);
    });

    // Write the aliases to the form
    this.serializer.serialize(serializedData);

    $(this.placeholderTarget).hide();

    if (length === 0) {
      emptyStateElem.show();
      containerElem.hide();
      countElem.text("0");
    } else {
      emptyStateElem.hide();
      containerElem.show().html("");
      countElem.text(length);

      R.forEachObjIndexed((alias, id) => {
        const card = this.#createAliasCard(alias, id);
        containerElem.append(card);
      }, this.aliases);
    }
  }
}
