import ApplicationController from "./application_controller";
import $ from "../helpers/cash_dom";
import Validator from "../helpers/validator";
import CardSelector from "../helpers/card_selector";

// Connects to data-controller="server-new"
export default class extends ApplicationController {
  static targets = ["form", "v1Card", "v2Card", "version"];
  static values = { ids: Array, serverIdCheckPath: String };

  connect() {
    this.validator = new Validator(this.formTarget);

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
          value: /\S+/i,
          errorMessage: "Server ID cannot contain whitespace",
        },
        {
          rule: "customRegexp",
          value: /\w+/i,
          errorMessage: "Server ID cannot contain any symbols",
        },
        {
          rule: "ajax",
          url: this.serverIdCheckPathValue,
          params: (value) => ({ id: value }),
          responseHandler: (response) => response.data.available,
          cache: true,
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
