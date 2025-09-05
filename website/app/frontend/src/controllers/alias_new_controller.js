import AliasController from "./alias_controller";
import $ from "../helpers/cash_dom";
import * as R from "ramda";
import * as bootstrap from "bootstrap";

// Connects to data-controller="alias-new"
export default class extends AliasController {
  connect() {
    super.connect();
    this.#initializeValidator();
  }

  create(_event) {
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

      const id = crypto.randomUUID();
      const value = $(this.valueTarget).val();

      this.dispatch("create", {
        detail: { id, server, community, value: R.toLower(value) },
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
              })
            )(R.values(this.aliasesOutlet.aliases)) ?? false;

          return !exists;
        },
        errorMessage: "Alias already exists",
      },
    ]);
  }
}
