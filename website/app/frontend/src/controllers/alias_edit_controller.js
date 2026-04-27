import AliasController from "./alias_controller";
import $ from "../helpers/cash_dom";
import * as R from "ramda";
import * as bootstrap from "bootstrap";

// Connects to data-controller="alias-edit"
export default class extends AliasController {
  connect() {
    super.connect();
    this.#initializeValidator();
  }

  edit({ detail: { alias } }) {
    this.alias = alias;

    this.selectedType = alias.server ? "server" : "community";
    this.cards.select(this.selectedType);
    this._showSection(this.selectedType);

    $(this.valueTarget).val(alias.value);

    this.setSlimSelected(
      this.communityIDTarget,
      `${alias.community?.community_id}:${alias.community?.community_name}`
    );

    this.setSlimSelected(
      this.serverIDTarget,
      `${alias.server?.server_id}:${alias.server?.server_name}`
    );
  }

  update(_event) {
    this.validator.validate().then((isValid) => {
      if (!isValid) return;

      let community = null;
      let server = null;

      if (this.selectedType === "server") {
        const [server_id, server_name] = $(this.serverIDTarget)
          .val()
          .split(":", 2);

        server = { server_id, server_name };
      } else {
        const [community_id, community_name] = $(this.communityIDTarget)
          .val()
          .split(":", 2);

        community = { community_id, community_name };
      }

      const value = $(this.valueTarget).val();

      this.dispatch("update", {
        detail: {
          id: this.alias.id,
          server,
          community,
          value: R.toLower(value),
        },
      });

      bootstrap.Modal.getOrCreateInstance(this.modal).hide();
    });
  }

  /////////////////////////////////////////////////////////////////////////////////////////////////

  #initializeValidator() {
    this.validator.addField(this.valueTarget, [
      { rule: "required" },
      { rule: "maxLength", value: 64 },
      {
        validator: (value, _context) => {
          value = R.toLower(value);

          const exists =
            R.find(
              R.where({
                value: R.equals(value),
                type: R.equals(this.selectedType),
                id: R.complement(R.equals(this.alias.id)),
              })
            )(R.values(this.aliasesOutlet.aliases)) ?? false;

          return !exists;
        },
        errorMessage: "Alias already exists",
      },
    ]);
  }
}
