import ApplicationController from "./application_controller";
import * as R from "ramda";
import $ from "../helpers/cash_dom";
import JustValidate from "just-validate";
import CardSelector from "../helpers/card_selector";

// Connects to data-controller="server-new"
export default class extends ApplicationController {
  static targets = ["form", "v1Card", "v2Card", "version"];
  static values = { ids: Array };

  connect() {
    this.validator = new JustValidate(this.formTarget, {
      submitFormAutomatically: true,
    });

    this.cards = new CardSelector({
      1: $(this.v1CardTarget),
      2: $(this.v2CardTarget),
    });

    this.#initializeValidator();
    this.#setVersion(2);
  }

  onVersionSelected(event) {
    const version = $(event.currentTarget).data("version");
    this.#setVersion(version);
  }

  //////////////////////////////////////////////////////////////////////////////

  #initializeValidator() {
    this.validator
      .addField("#server_server_id", [
        { rule: "required" },
        {
          rule: "customRegexp",
          value: /\S+/gi,
          errorMessage: "Server ID cannot contain whitespace",
        },
        {
          rule: "customRegexp",
          value: /\w+/gi,
          errorMessage: "Server ID cannot contain any symbols",
        },
        {
          validator: (value, _context) => {
            return !R.includes(value, this.idsValue);
          },
          errorMessage: "Server ID already exists",
        },
      ])
      .addField("#server_server_ip", [
        { rule: "required" },
        {
          rule: "customRegexp",
          value: /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/i,
          errorMessage: "Provide a valid public facing IPv4 address",
        },
      ])
      .addField("#server_server_port", [
        { rule: "required" },
        {
          rule: "customRegexp",
          value: /\d+/,
          errorMessage: "Provide a valid port",
        },
      ]);
  }

  #setVersion(version) {
    this.cards.select(version);
    $(this.versionTarget).val(version);
  }
}
